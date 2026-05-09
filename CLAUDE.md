# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

The build is driven by the **Makefile**, not SPM alone — `swift build` only produces the bare executable; the `.app` bundle, the two FinderSync extensions, and code signing are all assembled by the Makefile.

```bash
make build           # Compile main app + both extensions, assemble + sign .app at .build/go2shell.app
make install         # Build, copy to /Applications, run lsregister/pluginkit, restart Finder
make uninstall       # Remove from /Applications (does not clear App Group prefs)
make run             # Launch the built .app's settings window directly
make clean           # swift package clean + rm -rf .build .swiftpm
make release         # Build + zip to build/go2shell.zip + print sha256 (used by Homebrew tap)
make icon            # Regenerate Resources/AppIcon.icns from Resources/icon.png
make reset           # killall Finder
```

After `make install`, `pluginkit -e use -i com.solarhell.go2shell.{TerminalSync,CopySync}` runs automatically — but if extensions still don't appear, check `pluginkit -m -v | grep go2shell` and ensure they're not stuck in `disabled (unknown)` state.

There is no test target; `swift test` and `make test` are no-ops.

## Architecture

### Three-binary layout

This is **one app bundle that contains three separately-signed executables**:

1. **Main app** (`Sources/`, built by SPM) — has two roles depending on launch context, and the routing happens in `Sources/main.swift`:
   - If Finder is the frontmost app and `--show-ui` is not passed: behaves as a one-shot launcher. Calls `FinderManager` (ScriptingBridge → Finder) to get the front window's path, then `TerminalManager.openTerminal(atPath:)`, then exits.
   - Otherwise: boots SwiftUI (`Go2ShellApp` in `Views.swift`) and shows the settings window. The `LSUIElement` flag in `Resources/Info.plist` keeps it dockless until SwiftUI elevates the activation policy in `SettingsAppDelegate`.
2. **TerminalSync extension** (`FinderSyncExtension/TerminalSync/`) — Finder toolbar item "Open in Terminal".
3. **CopySync extension** (`FinderSyncExtension/CopySync/`) — Finder toolbar item "Copy Path".

The extensions are **not** SPM targets. The Makefile compiles each one with a direct `swiftc` invocation that links `-Xlinker -e -Xlinker _NSExtensionMain` (the FinderSync entry point) and embeds the `.appex` under `Contents/PlugIns/`. If you add Swift files to an extension, add them to the extension's `swiftc` line in the Makefile — SPM will not pick them up.

### Settings flow (App Group)

The preferred-terminal setting is shared between the main app and both extensions via the **`group.com.solarhell.go2shell` App Group** (`Sources/SharedDefaults.swift`). The extensions read it with their own `UserDefaults(suiteName:)` calls. If you add a new shared preference key, all three binaries need to agree on the suite name.

### Network-volume fallback

`FIFinderSyncController.targetedURL()` / `selectedItemURLs()` return `nil` on SMB/AFP mounts and some Finder views. Both extension controllers handle this by falling back to **AppleScript against `com.apple.finder`** (`frontFinderPathViaAppleScript`). This requires the `com.apple.security.temporary-exception.apple-events` entitlement scoped to `com.apple.finder` in each extension's `FinderSync.entitlements`. Don't broaden that scope — and don't add `--deep` to the main-app codesign, because it would overwrite the extensions' entitlements with the main app's.

### Finder/Terminal ScriptingBridge headers

`Sources/Finder.swift`, `Sources/Finder.h`, `Sources/Terminal.swift`, `Sources/Terminal.h` are **auto-generated from the `Finder.app` and `Terminal.app` `sdef` definitions**. They're checked in so SPM can compile without running `sdef` at build time. Treat them as opaque — don't hand-edit; regenerate from the system `.sdef` if Apple ships changes.

### `menu(for:)` must not block

Finder shows a "waiting" indicator if a FinderSync extension blocks in `menu(for:)`. Both controllers capture URLs synchronously (the FinderSync API is main-thread-only) and then dispatch the actual work — AppleScript fallback, terminal launch, pasteboard write — to a background queue. Keep this pattern when adding new menu actions.

### Adding a new terminal

Three places must agree:
1. `Sources/TerminalManager.swift` — `Terminal` enum + a `private static func open<Name>(atPath:)` (used by the main-app one-shot path).
2. `FinderSyncExtension/TerminalSync/TerminalLauncher.swift` — `SupportedTerminal` enum + a `case` in the AppleScript switch (used by the toolbar extension).
3. The `appPath` and `bundleID` (extension only) must match the actual installed location and bundle identifier.

The two enums are intentionally not shared because the extension does not import the main-app target.

## Code signing

Everything is **ad-hoc signed** (`codesign --sign -`). The Makefile signs each `.appex` individually with its own entitlements file *before* assembling the bundle, then signs the main app *without* `--deep` so the extension signatures and entitlements are preserved. If you ever need to re-sign manually, follow the same order: extensions first (with their entitlements), then the outer app (with `Resources/go2shell.entitlements`).

## Localization

Strings live in `Sources/L10n.swift` (a small enum-style wrapper) backed by `Resources/en.lproj/` and `Resources/zh-Hans.lproj/`. The default development region is `zh_CN` (per `Info.plist`); SPM's `defaultLocalization` is `en`.

## Distribution

`make release` is what the GitHub Actions release workflow runs to produce `go2shell.zip` for the Homebrew tap at `dingtang2008/tap`. The `.github/workflows/update-homebrew.yml` workflow updates the cask formula on release.
