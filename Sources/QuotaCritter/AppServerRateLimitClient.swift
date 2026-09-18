import Darwin
import Foundation

enum AppServerProtocol {
    static let maxResponseBytes = 65_536
    static let rateLimitRequestID = 2
    static let requestLines = [
        #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"quota-creature","title":"QuotaCreature","version":"0.1.0"}}}"#,
        #"{"method":"initialized","params":{}}"#,
        #"{"method":"account/rateLimits/read","id":2}"#
    ]

    static func parseRateLimitResponse(_ data: Data) throws -> UsageSnapshot? {
        guard data.count <= maxResponseBytes else {
            throw UsageError.oversizedResponse
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard envelope.id == rateLimitRequestID else {
            return nil
        }
        guard let primary = envelope.result?.rateLimits?.primary else {
            throw UsageError.invalidRateLimit
        }

        return try UsageSnapshot(
            primary: RateLimitWindow(
                usedPercent: primary.usedPercent,
                windowDurationMins: primary.windowDurationMins,
                resetsAt: primary.resetsAt
            ),
            secondary: try envelope.result?.rateLimits?.secondary.map {
                try RateLimitWindow(
                    usedPercent: $0.usedPercent,
                    windowDurationMins: $0.windowDurationMins,
                    resetsAt: $0.resetsAt
                )
            }
        )
    }
}

private struct ResponseEnvelope: Decodable {
    let id: Int?
    let result: RateLimitResult?
}

private struct RateLimitResult: Decodable {
    let rateLimits: RateLimits?
}

private struct RateLimits: Decodable {
    let primary: RateLimitPayload?
    let secondary: RateLimitPayload?
}

private struct RateLimitPayload: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: TimeInterval
}

enum CodexExecutable {
    private static let allowedEnvironmentKeys = ["HOME", "PATH", "TMPDIR", "LANG"]

    static func sanitizedEnvironment(_ environment: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: allowedEnvironmentKeys.compactMap { key in
            environment[key].map { (key, $0) }
        })
    }

    static func runtimeEnvironment() -> [String: String] {
        sanitizedEnvironment(
            Dictionary(uniqueKeysWithValues: allowedEnvironmentKeys.compactMap { key in
                environmentValue(for: key).map { (key, $0) }
            })
        )
    }

    static func locate() throws -> URL {
        guard let homePath = environmentValue(for: "HOME"), homePath.hasPrefix("/") else {
            throw UsageError.codexNotFound
        }
        let home = URL(fileURLWithPath: homePath)

        for candidate in candidatePaths(
            path: environmentValue(for: "PATH"),
            home: home,
            nvmVersions: nvmVersions(in: home)
        ) {
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw UsageError.codexNotFound
    }

    static func candidatePaths(path: String?, home: URL, nvmVersions: [String]) -> [URL] {
        let pathCandidates = (path ?? "").split(separator: ":").compactMap { entry -> URL? in
            guard entry.hasPrefix("/") else {
                return nil
            }
            return URL(fileURLWithPath: String(entry))
                .appendingPathComponent("codex")
                .standardizedFileURL
        }
        let knownCandidates = [
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex")
        ]
        let nvmCandidates = nvmVersions.map {
            home.appendingPathComponent(".nvm/versions/node/\($0)/bin/codex")
        }

        return (pathCandidates + knownCandidates + nvmCandidates).reduce(into: []) { paths, candidate in
            if !paths.contains(candidate) {
                paths.append(candidate)
            }
        }
    }

    private static func environmentValue(for key: String) -> String? {
        key.withCString { name in
            guard let value = getenv(name) else {
                return nil
            }
            return String(cString: value)
        }
    }

    private static func nvmVersions(in home: URL) -> [String] {
        let nodeRoot = home.appendingPathComponent(".nvm/versions/node")
        return (try? FileManager.default.contentsOfDirectory(
            at: nodeRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ))?.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            return url.lastPathComponent
        } ?? []
    }
}

struct AppServerRateLimitClient: Sendable {
    func readRateLimits() async -> Result<UsageSnapshot, UsageError> {
        let runner = AppServerRateLimitRunner()
        return await Task.detached(priority: .utility) { [runner] in
            runner.run()
        }.value
    }
}

private final class AppServerRateLimitRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var child: Process?
    private var didTimeOut = false

    func run() -> Result<UsageSnapshot, UsageError> {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let timeout = DispatchWorkItem { [weak self] in
            self?.timeOut()
        }

        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + 8,
            execute: timeout
        )
        defer {
            timeout.cancel()
            stopChild()
        }

        do {
            process.executableURL = try CodexExecutable.locate()
            process.arguments = ["app-server", "--listen", "stdio://"]
            process.environment = CodexExecutable.runtimeEnvironment()
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            remember(process)

            if timedOut {
                return .failure(.timedOut)
            }

            for line in AppServerProtocol.requestLines {
                input.fileHandleForWriting.write(Data((line + "\n").utf8))
            }

            guard let snapshot = try readSnapshot(from: output.fileHandleForReading) else {
                return .failure(timedOut ? .timedOut : .noResponse)
            }
            return .success(snapshot)
        } catch let error as UsageError {
            return .failure(error)
        } catch {
            return .failure(.launchFailed)
        }
    }

    private func readSnapshot(from handle: FileHandle) throws -> UsageSnapshot? {
        var buffer = Data()

        while let chunk = try handle.read(upToCount: 4_096), !chunk.isEmpty {
            guard buffer.count + chunk.count <= AppServerProtocol.maxResponseBytes else {
                throw UsageError.oversizedResponse
            }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)

                if !line.isEmpty, let snapshot = try AppServerProtocol.parseRateLimitResponse(line) {
                    return snapshot
                }
            }
        }

        guard !buffer.isEmpty else {
            return nil
        }
        return try AppServerProtocol.parseRateLimitResponse(buffer)
    }

    private var timedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didTimeOut
    }

    private func remember(_ process: Process) {
        lock.lock()
        child = process
        let shouldTerminate = didTimeOut
        lock.unlock()

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    private func timeOut() {
        lock.lock()
        didTimeOut = true
        let process = child
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func stopChild() {
        lock.lock()
        let process = child
        child = nil
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }
}
