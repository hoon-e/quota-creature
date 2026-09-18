# Contributing

## Local workflow

```zsh
swift test
swift build
swift run QuotaCritter
```

Keep the project dependency-free unless a new dependency is justified in the
design and threat model. Add tests before nontrivial behavior, especially at
the App Server, process, parsing, or installation boundary.

## Security boundaries

Do not add transcript parsing, credential access, arbitrary command input,
network listeners, direct HTTP/WebSocket calls, analytics, persistence, or an
auto-updater without a reviewed change to `docs/THREAT_MODEL.md` and
`SECURITY.md`.

Use synthetic JSON in tests. Never commit credentials, account identifiers,
prompts, real usage output, or screenshots containing personal data.
