import Cocoa
import FinderSync
import os

@objc(FinderSyncController)
final class FinderSyncController: FIFinderSync {

    private static let logger = Logger(subsystem: "com.solarhell.go2shell.CopySync", category: "main")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}

    override var toolbarItemName: String { "Copy Path" }
    override var toolbarItemToolTip: String {
        "Copy current directory, or full paths of selected items"
    }
    override var toolbarItemImage: NSImage {
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copy Path") ?? NSImage()
        image.isTemplate = true
        return image
    }

    // Capture URLs synchronously (FinderSync API is main-thread-only), then
    // do the AppleScript fallback + pasteboard write on a background queue so
    // the menu callback returns immediately. Blocking in `menu(for:)` makes
    // Finder show a "waiting" indicator.
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        log("menu(for:) called kind=\(menuKind.rawValue)")
        guard menuKind == .toolbarItemMenu else { return nil }
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        let targeted = controller.targetedURL()
        DispatchQueue.global(qos: .userInitiated).async {
            Self.copyPathToPasteboard(selected: selected, targeted: targeted)
        }
        return nil
    }

    private static func copyPathToPasteboard(selected: [URL], targeted: URL?) {
        let urls: [URL]
        if !selected.isEmpty {
            urls = selected
        } else if let t = targeted, t.isFileURL, !t.path.isEmpty {
            urls = [t]
        } else if let p = frontFinderPathViaAppleScript() {
            urls = [URL(fileURLWithPath: p)]
        } else {
            urls = []
        }
        let text = urls.map { $0.path }.joined(separator: "\n")
        logger.log("selected=\(selected.count, privacy: .public) targeted=\(targeted?.path ?? "nil", privacy: .public) text=\(text, privacy: .public)")
        guard !text.isEmpty else { return }
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
    }

    /// Fallback for when the FinderSync API returns nil URLs (network
    /// mounts, some Finder views). Requires the com.apple.finder apple-events
    /// exception in the extension's entitlements.
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

    private func log(_ message: String) {
        Self.logger.log("\(message, privacy: .public)")
    }
}
