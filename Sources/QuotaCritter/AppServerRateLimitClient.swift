import Darwin
import Foundation

enum AppServerProtocol {
    static let maxResponseBytes = 65_536
    static let rateLimitRequestID = 2
    static let requestLines = [
        #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"quota-creature","title":"QuotaCreature","version":"1.0.0"}}}"#,
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
        guard let rateLimits = envelope.result?.rateLimits else {
            throw UsageError.invalidRateLimit
        }

        if let individualLimit = rateLimits.individualLimit {
            return .monthlyCredits(
                try MonthlyCreditLimit(
                    limit: individualLimit.limit,
                    used: individualLimit.used,
                    remainingPercent: individualLimit.remainingPercent,
                    resetsAt: individualLimit.resetsAt
                )
            )
        }

        guard let primary = rateLimits.primary else {
            throw UsageError.invalidRateLimit
        }

        return try .rateLimits(
            primary: RateLimitWindow(
                usedPercent: primary.usedPercent,
                windowDurationMins: primary.windowDurationMins,
                resetsAt: primary.resetsAt
            ),
            secondary: try rateLimits.secondary.map {
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
    let individualLimit: IndividualLimitPayload?
}

private struct RateLimitPayload: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: TimeInterval
}

private struct IndividualLimitPayload: Decodable {
    let limit: String
    let used: String
    let remainingPercent: Int
    let resetsAt: TimeInterval
}

private enum LocalExecutable {
    static func candidatePaths(
        named executable: String,
        path: String?,
        home: URL,
        nvmVersions: [String]
    ) -> [URL] {
        let pathCandidates = (path ?? "").split(separator: ":").compactMap { entry -> URL? in
            guard entry.hasPrefix("/") else {
                return nil
            }
            return URL(fileURLWithPath: String(entry))
                .appendingPathComponent(executable)
                .standardizedFileURL
        }
        let knownCandidates = [
            home.appendingPathComponent(".local/bin/\(executable)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(executable)"),
            URL(fileURLWithPath: "/usr/local/bin/\(executable)")
        ]
        let nvmCandidates = nvmVersions.map {
            home.appendingPathComponent(".nvm/versions/node/\($0)/bin/\(executable)")
        }

        return (pathCandidates + knownCandidates + nvmCandidates).reduce(into: []) { paths, candidate in
            if !paths.contains(candidate) {
                paths.append(candidate)
            }
        }
    }

    static func nvmVersions(in home: URL) -> [String] {
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

enum CodexExecutable {
    private static let allowedEnvironmentKeys = ["HOME", "PATH", "TMPDIR", "LANG"]

    static func sanitizedEnvironment(_ environment: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: allowedEnvironmentKeys.compactMap { key in
            environment[key].map { (key, $0) }
        })
    }

    static func runtimeEnvironment(for executable: URL? = nil) -> [String: String] {
        var environment = Dictionary(
            uniqueKeysWithValues: allowedEnvironmentKeys.compactMap { key in
                environmentValue(for: key).map { (key, $0) }
            }
        )
        if let executable {
            let directory = executable.deletingLastPathComponent().path
            let path = environment["PATH"] ?? ""
            environment["PATH"] = path.isEmpty ? directory : "\(directory):\(path)"
        }
        return sanitizedEnvironment(environment)
    }

    static func locate() throws -> URL {
        guard let homePath = environmentValue(for: "HOME"), homePath.hasPrefix("/") else {
            throw UsageError.codexNotFound
        }
        let home = URL(fileURLWithPath: homePath)
        let path = environmentValue(for: "PATH")

        for candidate in candidatePaths(
            path: path,
            home: home,
            nvmVersions: nvmVersions(in: home)
        ) {
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        let shellPath = environmentValue(for: "SHELL") ?? "/bin/zsh"
        if let candidate = loginShellCandidate(
            path: path,
            home: home,
            shell: URL(fileURLWithPath: shellPath)
        ) {
            return candidate
        }

        throw UsageError.codexNotFound
    }

    static func candidatePaths(path: String?, home: URL, nvmVersions: [String]) -> [URL] {
        LocalExecutable.candidatePaths(
            named: "codex",
            path: path,
            home: home,
            nvmVersions: nvmVersions
        )
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
        LocalExecutable.nvmVersions(in: home)
    }

    static func loginShellCandidate(path: String?, home: URL, shell: URL) -> URL? {
        guard shell.path.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: shell.path)
        else {
            return nil
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = shell
        process.arguments = ["-ilc", "command -v codex 2>/dev/null"]
        process.environment = sanitizedEnvironment([
            "HOME": home.path,
            "PATH": path ?? "/usr/bin:/bin",
            "TMPDIR": environmentValue(for: "TMPDIR") ?? "/tmp",
            "LANG": environmentValue(for: "LANG") ?? "C.UTF-8"
        ])
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeout = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + 8,
            execute: timeout
        )
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()

        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        for line in text.split(whereSeparator: \.isNewline).reversed() {
            let path = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard path.hasPrefix("/"),
                  FileManager.default.isExecutableFile(atPath: path)
            else {
                continue
            }
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return nil
    }
}

enum ClaudeExecutable {
    static func candidatePaths(path: String?, home: URL, nvmVersions: [String]) -> [URL] {
        LocalExecutable.candidatePaths(
            named: "claude",
            path: path,
            home: home,
            nvmVersions: nvmVersions
        )
    }

    static func isInstalled() -> Bool {
        let homePath = NSHomeDirectory()
        guard homePath.hasPrefix("/") else {
            return false
        }

        let home = URL(fileURLWithPath: homePath)
        return candidatePaths(
            path: ProcessInfo.processInfo.environment["PATH"],
            home: home,
            nvmVersions: LocalExecutable.nvmVersions(in: home)
        ).contains {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
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

        defer {
            timeout.cancel()
            stopChild()
        }

        do {
            let executable = try CodexExecutable.locate()
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 8,
                execute: timeout
            )
            process.executableURL = executable
            process.arguments = ["app-server", "--listen", "stdio://"]
            process.environment = CodexExecutable.runtimeEnvironment(for: executable)
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
