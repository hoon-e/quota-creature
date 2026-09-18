# Contributing

## Local workflow

```zsh
swift test
swift build
swift run QuotaCreature
```

Keep the project dependency-free unless a new dependency is justified in the
design and threat model. Add tests before nontrivial behavior, especially at
the App Server, process, parsing, or installation boundary.

## Adding a creature

Add one `CreatureStyle` entry to `CreatureStyle.all` in
`Sources/QuotaCritter/CreatureStyle.swift`:

- Use a unique, stable lowercase `id` and a short `displayName`.
- Supply exactly three frames. Each frame must contain 16 rows of 16
  characters using only `B` for body pixels and `.` for empty pixels.
- Keep the face area around columns 5-10 and rows 6-10 filled so the shared
  usage expression remains readable.
- Use original source-drawn art. Do not add downloaded assets or runtime
  plug-ins.

Run `swift test` before opening a pull request. The catalog tests reject
duplicate metadata, invalid frame sizes, and unsupported pixel characters.

## Security boundaries

Do not add transcript parsing, credential access, arbitrary command input,
network listeners, direct HTTP/WebSocket calls, analytics, sensitive-data
persistence, or an auto-updater without a reviewed change to
`docs/THREAT_MODEL.md` and `SECURITY.md`.

Use synthetic JSON in tests. Never commit credentials, account identifiers,
prompts, real usage output, or screenshots containing personal data.
