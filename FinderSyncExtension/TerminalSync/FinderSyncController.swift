import Cocoa
import FinderSync
import os

@objc(FinderSyncController)
final class FinderSyncController: FIFinderSync {

    private static let logger = Logger(subsystem: "com.solarhell.go2shell.TerminalSync", category: "controller")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}

    override var toolbarItemName: String { "Open in Terminal" }
    override var toolbarItemToolTip: String { "Open a terminal at the current Finder directory" }
    override var toolbarItemImage: NSImage {
        let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Open in Terminal") ?? NSImage()
        image.isTemplate = true
        return image
    }

    // Capture the FinderSync URLs synchronously on the main thread (the API
    // is main-thread-only), then hand the rest — AppleScript fallback and
    // Terminal launch — to a background queue. Blocking inside `menu(for:)`
    // freezes Finder's UI and causes the "waiting" indicator on network
    // paths where AppleScript takes a beat to answer.
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .toolbarItemMenu else { return nil }
        let controller = FIFinderSyncController.default()
        let targeted = controller.targetedURL()
        let selected = controller.selectedItemURLs()?.first
        DispatchQueue.global(qos: .userInitiated).async {
            let path = Self.resolvePath(targeted: targeted, selected: selected) ?? Self.realUserHome()
            TerminalLauncher.open(path: path)
        }
        return nil
    }

    /// Resolve the local folder the user is currently looking at. First
    /// uses the URLs we captured from the FinderSync API; if they're nil
    /// (happens on network mounts, server browsers, a few other Finder
    /// views), falls back to asking Finder via AppleScript.
    private static func resolvePath(targeted: URL?, selected: URL?) -> String? {
        logger.log("targeted=\(targeted?.absoluteString ?? "nil", privacy: .public) selected=\(selected?.absoluteString ?? "nil", privacy: .public)")

        if let url = targeted, url.isFileURL, !url.path.isEmpty {
            return url.path
        }
        if let url = selected, url.isFileURL, !url.path.isEmpty {
            // `hasDirectoryPath` reads the URL's trailing-slash hint; Finder
            // sets it correctly so we don't need to stat the file.
            return url.hasDirectoryPath ? url.path : url.deletingLastPathComponent().path
        }
        if let p = frontFinderPathViaAppleScript() {
            logger.log("applescript fallback path=\(p, privacy: .public)")
            return p
        }
        return nil
    }

    /// Ask Finder directly for the frontmost window's target path. Used when
    /// the FinderSync API returns nil (e.g. network volumes, some server
    /// browsers). Requires the com.apple.finder apple-events exception in
    /// the extension's entitlements.
    private static func frontFinderPathViaAppleScript() -> String? {
        let source = """
        tell application "Finder"
            try
                set theTarget to (target of front window) as alias
                return POSIX path of theTarget
            on error
                return ""
            end try
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error = error {
            logger.error("Finder AppleScript failed: \(error, privacy: .public)")
            return nil
        }
        let path = descriptor.stringValue ?? ""
        return path.isEmpty ? nil : path
    }

    /// Real user home, bypassing the sandbox container. `NSHomeDirectory()`
    /// in a sandboxed extension returns the fake container $HOME, so we read
    /// passwd directly.
    private static func realUserHome() -> String {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return "/tmp"
        }
        return String(cString: dir)
    }
}
