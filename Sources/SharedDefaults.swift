import Foundation

/// Shared UserDefaults between the main app and the FinderSync extensions.
/// Falls back to `.standard` if the App Group is unavailable (e.g. unsigned dev run).
enum SharedDefaults {
    static let suiteName = "group.com.solarhell.go2shell"

    nonisolated(unsafe) static let shared: UserDefaults = {
        UserDefaults(suiteName: suiteName) ?? .standard
    }()
}
