# SwiftMath — Vendored Third-Party Fork

**Upstream:** github.com/mgriebling/SwiftMath, itself a Swift port of github.com/kostub/iosMath. This directory is a working checkout of the Brainblast fork (github.com/Archetapp/SwiftMath).

**Treat as vendored — do not modify unless syncing from upstream or patching a specific bug.** If you need to patch, keep the diff surgical and document it in the commit message.

## Purpose

A pure-Swift LaTeX math typesetter. Parses math-mode LaTeX into an `MTMathList`, typesets via `MTTypesetter` using LaTeX's layout rules, and renders into `UILabel` / `NSView` equivalents (`MTMathUILabel`) or `CGImage` (`MTMathImage`). Ships its own math fonts in `mathFonts.bundle`.

## Consumers

- `BrainblastWidgets` (`Brainblast-iOS/BrainBlastUI`) — `WidgetMarkdownLaTeXText` renders Daily Question math via `MathImage`. Widget extensions run under a ~30MB memory cap, so the MathJax/JavaScriptCore-based `LaTeXSwiftUI` renderer cannot be used there.

Everywhere else the workspace uses `LaTeXSwiftUI` (MathJax-based) for equation rendering. If you add or remove a consumer, update this file.

## Build & test

```
cd SwiftMath && swift build
cd SwiftMath && swift test
```

## Don't touch

Everything under `Sources/SwiftMath/` follows the upstream layout (`MathRender/`, `MathBundle/`, `mathFonts.bundle`). Keep it that way so upstream syncs remain mechanical. `EXAMPLES.md`, `MISSING_FEATURES.md`, and `MULTILINE_IMPLEMENTATION_NOTES.md` are upstream documentation.
