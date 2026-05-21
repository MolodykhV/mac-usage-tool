# Plumage Bar

> A lightweight CPU / GPU / RAM monitor for the macOS Tahoe menu bar, with Liquid Glass design.
>
> Лёгкий монитор CPU / GPU / RAM в меню-баре macOS Tahoe c дизайном Liquid Glass.

**Status: early development (Stage 1 — scaffolding).**

## Highlights

- Native, written in Swift 6 with SwiftUI + AppKit.
- Zero third-party runtime dependencies — only Apple system frameworks.
- Apple Silicon (arm64) only. Requires **macOS 26 Tahoe** or later (Liquid Glass).
- Tiny footprint: target budget is **≤ 30 MB RSS** and **< 0.5% CPU** when idle.
- English and Russian out of the box; new languages are a one-PR change.

## Why another menu-bar monitor?

[Stats](https://github.com/exelban/stats) is excellent and the obvious comparison.
Plumage Bar's niche is being smaller in scope, modern in visuals (Liquid Glass), and
test-first about the things that hurt long-running menu-bar processes — leaks, retain
cycles in `NSStatusItem`/`NSHostingView`, and runaway energy use.

## Building from source

Requires macOS 26+ and Xcode 26 (Swift 6.3).

```bash
# Build the executable
make build

# Run the unit tests
make test

# Assemble the .app bundle into ./dist/
make app

# Lint the codebase (swift-format)
make lint
```

Open `Package.swift` in Xcode for IDE debugging.

## Distribution

Plumage Bar ships through **GitHub Releases** as a notarized DMG once a Developer ID
is available; until then, builds are unsigned ad-hoc and require the standard
right-click → **Open** dance on first launch. App Store distribution is not planned
(the GPU module relies on a private `IOReport` SPI that App Review will not pass).

## Contributing

This is an open-source project; issues and PRs are welcome once Stage 3 lands.

## License

[MIT](LICENSE) © 2026 Vitaliy Molodykh
