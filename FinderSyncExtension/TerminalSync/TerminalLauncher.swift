import AppKit
import Foundation
import os

enum SupportedTerminal: String, CaseIterable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case wezterm = "WezTerm"

    var bundleID: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .ghostty: return "com.mitchellh.ghostty"
        case .wezterm: return "com.github.wez.wezterm"
        }
    }

    var appPath: String {
        switch self {
        case .terminal: return "/System/Applications/Utilities/Terminal.app"
        case .iterm: return "/Applications/iTerm.app"
        case .warp: return "/Applications/Warp.app"
        case .ghostty: return "/Applications/Ghostty.app"
        case .wezterm: return "/Applications/WezTerm.app"
        }
    }

    var isInstalled: Bool { FileManager.default.fileExists(atPath: appPath) }
}

enum TerminalLauncher {
    private static let groupDefaults = UserDefaults(suiteName: "group.com.solarhell.go2shell")
    private static let logger = Logger(subsystem: "com.solarhell.go2shell.TerminalSync", category: "launcher")

    static func open(path: String) {
        let name = groupDefaults?.string(forKey: "PreferredTerminal") ?? "Terminal"
        var terminal = SupportedTerminal(rawValue: name) ?? .terminal
        if !terminal.isInstalled { terminal = .terminal }

        // Use `tell application id "..."`: AppleScript resolves via LaunchServices,
        // launches the app if needed, and waits until AppleEvents are ready —
        // much more reliable than name-based tell plus a manual delay.
        let source: String
        switch terminal {
        case .terminal:
            source = """
            tell application id "\(terminal.bundleID)"
                activate
                do script "cd \(singleQuoted(path))"
            end tell
            """
        case .iterm:
            source = """
            tell application id "\(terminal.bundleID)"
                activate
                try
                    tell current window to create tab with default profile
                on error
                    create window with default profile
                end try
                tell current session of current window
                    write text "cd \(singleQuoted(path))"
                end tell
            end tell
            """
        case .warp:
            source = """
            tell application id "\(terminal.bundleID)" to activate
            do shell script "open " & quoted form of "warp://action/new_tab?path=\(urlEncode(path))"
            """
        case .ghostty:
            source = """
            tell application id "\(terminal.bundleID)" to activate
            do shell script "open " & quoted form of "ghostty://new?cwd=\(urlEncode(path))"
            """
        case .wezterm:
            source = """
            tell application id "\(terminal.bundleID)" to activate
            """
        }

        logger.log("terminal=\(terminal.rawValue, privacy: .public) path=\(path, privacy: .public)")

        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if result == nil {
            logger.error("AppleScript failed: \(error?.description ?? "nil", privacy: .public)")
        }
    }

    /// Shell-safe single-quoted wrapping. `'a b'` for spaces; `'\''` for
    /// embedded single quotes.
    private static func singleQuoted(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }
}
