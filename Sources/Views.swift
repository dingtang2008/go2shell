import Cocoa
import SwiftUI

// MARK: - SwiftUI App（不带 @main，由 main.swift 手动调用）

struct Go2ShellApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) var appDelegate

    var body: some Scene {
        Window("go2shell", id: "main") {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Views

struct MainView: View {
    @AppStorage("PreferredTerminal", store: SharedDefaults.shared)
    private var preferredTerminal = "Terminal"

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)

                Text("go2shell")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.appSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)

            Divider()
                .padding(.horizontal)

            // Settings Section
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                    Text(L10n.preferredTerminal)
                        .font(.headline)
                    Spacer()
                }

                let installed = TerminalManager.Terminal.allCases.filter { $0.isInstalled }
                let notInstalled = TerminalManager.Terminal.allCases.filter { !$0.isInstalled }

                Picker("", selection: $preferredTerminal) {
                    ForEach(installed, id: \.rawValue) { terminal in
                        HStack {
                            if let icon = getAppIcon(for: terminal.appPath) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(terminal.displayName)
                        }
                        .tag(terminal.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if !notInstalled.isEmpty {
                    Divider()

                    ForEach(notInstalled, id: \.rawValue) { terminal in
                        HStack {
                            Image(systemName: "questionmark.app.dashed")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            Text(terminal.displayName)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            Text(L10n.notInstalled)
                                .font(.caption)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        }
                    }
                }
                Text(L10n.fallbackNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            // Usage Instructions
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(L10n.instructionsTitle)
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    instructionRow(
                        icon: "1.circle.fill", color: .blue,
                        title: L10n.step1Title,
                        detail: L10n.step1Detail
                    )

                    Divider()

                    instructionRow(
                        icon: "2.circle.fill", color: .green,
                        title: L10n.step2Title,
                        detail: L10n.step2Detail
                    )

                    Divider()

                    instructionRow(
                        icon: "gearshape.fill", color: .orange,
                        title: L10n.settingsTitle,
                        detail: L10n.settingsDetail
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)

            Spacer()

            Text(L10n.tipOpenSettings)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        }
        .frame(width: 500, height: 700)
    }

    private func instructionRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func getAppIcon(for appPath: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: appPath) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }
}
