import AppKit
import SwiftUI
import UficastCore

@main
struct UficastMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--preview-calendar-menu") {
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            application.finishLaunching()
            CalendarMenuPreview().run()
            return
        }
        if CommandLine.arguments.contains("--verify-menu-clock") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do { try MenuBarClockVerification.run() }
            catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--preview-status-clock"), CommandLine.arguments.indices.contains(index + 1) {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try StatusClockPreview.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                print("Wrote light/dark status clock preview.")
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--preview-calendar"), CommandLine.arguments.indices.contains(index + 1) {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            if CommandLine.arguments.contains("--dark") { application.appearance = NSAppearance(named: .darkAqua) }
            let calendar = MenuBarCalendarView()
            calendar.wantsLayer = true
            calendar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            calendar.reset(to: ISO8601DateFormatter().date(from: "2027-07-18T12:00:00Z")!)
            let window = NSWindow(contentRect: calendar.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = calendar
            do {
                try ViewPreview.write(calendar, to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                print("Wrote native NSDatePicker calendar preview (\(calendar.frame.width) × \(calendar.frame.height) points).")
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--verify-ai-text") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try AITextVerification.run()
                print("PASS: AI text rich-text round trip, pasteboards, panel controls and clipboard/link flows (cancel, retry, text source, refused links, formatting fallback).")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-keyboard-shortcuts") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try KeyboardVerification.run()
                print("PASS: Settings shortcuts, Find, Escape precedence and hotkey recording priority.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-script-feedback") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try LauncherPanelController().verifyScriptRunFeedback()
                print("PASS: script failure feedback, exact argument restoration, explicit retry and stale-result handling.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-usage-order") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try LauncherPanelController().verifyUsageOrder()
                print("PASS: launches reorder the empty search by frequency, are reported for saving and survive a restart.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-calculator") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try LauncherPanelController().verifyCalculator()
                print("PASS: calculator rows, copy on Enter, history suggestions, Tab edit and remembered draft.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-pull-requests") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try LauncherPanelController().verifyPullRequests()
                print("PASS: pull-request mode lists, filters, opens, leaves and ignores late results.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-alias-editor") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try AliasEditorVerification.run()
                print("PASS: inline alias editing, Escape, validation, save, removal and draft cleanup.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-shortcut-recorder") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try ShortcutRecorderVerification.run()
                print("PASS: inline double-click recording, Escape cancellation, capture, clear and focus cleanup.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--verify-native-icons") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            do {
                try LauncherPanelController().verifyNativeIconRefresh()
                print("PASS: catalog icons updated existing launcher cells without moving rows.")
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        if let flag = CommandLine.arguments.firstIndex(where: { ["--preview-launcher", "--preview-settings", "--preview-script-editor"].contains($0) }) {
            guard CommandLine.arguments.indices.contains(flag + 1) else {
                print("Provide an output PNG path for the preview.")
                exit(2)
            }
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            application.finishLaunching()
            if CommandLine.arguments.contains("--dark") { application.appearance = NSAppearance(named: .darkAqua) }
            let path = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            do {
                if CommandLine.arguments[flag] == "--preview-launcher" {
                    try LauncherPanelController().renderPreview(to: path, argumentMode: CommandLine.arguments.contains("--argument"),
                        emptyArgument: CommandLine.arguments.contains("--empty-argument"), failure: CommandLine.arguments.contains("--failure"),
                        calculation: CommandLine.arguments.contains("--calculation"))
                } else {
                    let model = ViewPreview.settingsModel()
                    if CommandLine.arguments.contains("--general") { model.section = "General" }
                    if CommandLine.arguments.contains("--shortcut-guide") {
                        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                                              styleMask: [.borderless], backing: .buffered, defer: false)
                        window.contentView = NSHostingView(rootView: ShortcutGuideSheet(action: .rewrite, onDone: {}))
                        try ViewPreview.write(window.contentView!, to: path)
                    } else if CommandLine.arguments[flag] == "--preview-script-editor" {
                        var command = model.configuration.scripts[0]
                        command.requiresArgument = true
                        command.argumentPlaceholder = "Search text"
                        command.interpreter = "/usr/bin/python3"
                        command.resultMode = .openURL
                        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 720),
                                              styleMask: [.borderless], backing: .buffered, defer: false)
                        window.contentView = NSHostingView(rootView: ScriptEditor(model: model, script: command))
                        try ViewPreview.write(window.contentView!, to: path)
                    } else {
                        let controller = SettingsWindowController(model: model)
                        // Development-only: a taller window shows sections further down General.
                        if let index = CommandLine.arguments.firstIndex(of: "--height"), CommandLine.arguments.indices.contains(index + 1),
                           let height = Double(CommandLine.arguments[index + 1]) {
                            controller.window?.setContentSize(NSSize(width: 980, height: height))
                        }
                        try controller.renderPreview(to: path)
                    }
                }
                print("Wrote offscreen preview: \(path.path)")
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--catalog-summary") {
            let start = ContinuousClock.now
            let snapshot = ApplicationCatalog.discover(roots: ApplicationCatalog.defaultRoots)
            print("Applications: \(snapshot.entries.count); unavailable roots: \(snapshot.unavailableRoots.count); discovery: \(start.duration(to: .now))")
            return
        }
        if CommandLine.arguments.contains("--diagnostics") {
            let values: [String: Any] = [
                "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unbundled",
                "bundlePath": Bundle.main.bundlePath,
                "shortcut": "Command + Space by default; configurable in Settings",
                "requiresAccessibility": false,
                "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]),
               let value = String(data: data, encoding: .utf8) { print(value) }
            return
        }
        let coordinator = InstanceCoordinator()
        do {
            guard try coordinator.becomePrimary() else { coordinator.revealPrimary(); return }
        } catch {
            NSApplication.shared.setActivationPolicy(.regular)
            NSAlert(error: error).runModal()
            return
        }
        let application = NSApplication.shared
        let controller = AppController()
        coordinator.onReopen = { [weak controller] in controller?.revealLauncher() }
        application.delegate = controller
        withExtendedLifetime((controller, coordinator)) { application.run() }
        coordinator.stop()
    }
}
