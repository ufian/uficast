import AppKit
import UficastCore

/// Development-only offscreen rendering. Does not register hotkeys or operate other apps.
@MainActor
enum ViewPreview {
    /// Public documentation fixtures only: never discover apps or load user config.
    static let applications: [LauncherEntry] = [
        LauncherEntry(id: "app:preview-calculator", name: "Calculator", fileURL: URL(fileURLWithPath: "/System/Applications/Calculator.app"), alias: "calc"),
        LauncherEntry(id: "app:preview-calendar", name: "Calendar", fileURL: URL(fileURLWithPath: "/System/Applications/Calendar.app"), alias: "cal"),
        LauncherEntry(id: "app:preview-notes", name: "Notes", fileURL: URL(fileURLWithPath: "/System/Applications/Notes.app"), alias: "notes"),
        LauncherEntry(id: "app:preview-safari", name: "Safari", fileURL: URL(fileURLWithPath: "/Applications/Safari.app"), alias: "web"),
        LauncherEntry(id: "app:preview-terminal", name: "Terminal", fileURL: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), alias: "term"),
    ]

    static var command: ScriptCommand {
        ScriptCommand(id: "preview-search", name: "Search Example", alias: "search",
                      path: "/tmp/uficast-example/browser-search.py", interpreter: "/usr/bin/python3",
                      requiresArgument: true, argumentPlaceholder: "Search text", resultMode: .openURL)
    }

    /// Fictional repositories and inert example.com URLs; never loaded from GitHub.
    static let pullRequests: [PullRequest] = [
        PullRequest(number: 42, title: "Keep launcher results stable while application icons load",
                    url: URL(string: "https://example.com/demo/launcher/pull/42")!, repository: "demo/launcher",
                    createdAt: Date(timeIntervalSince1970: 1_800_000_000), isDraft: false),
        PullRequest(number: 41, title: "Add keyboard navigation to the settings window",
                    url: URL(string: "https://example.com/demo/launcher/pull/41")!, repository: "demo/launcher",
                    createdAt: Date(timeIntervalSince1970: 1_799_900_000), isDraft: false),
        PullRequest(number: 18, title: "Document the local development workflow",
                    url: URL(string: "https://example.com/demo/docs/pull/18")!, repository: "demo/docs",
                    createdAt: Date(timeIntervalSince1970: 1_799_800_000), isDraft: true),
    ]

    static func settingsModel() -> SettingsModel {
        let model = SettingsModel()
        model.isBusy = false
        model.status = "Settings ready."
        model.shortcutStatus = "Release matching Spotlight/Raycast shortcuts if needed."
        model.configuration.scripts = [command]
        model.catalogEntries = applications
        for entry in applications {
            model.configuration.applications[entry.id] = AppOverride(alias: entry.alias)
        }
        model.configuration.applications["app:preview-terminal"]?.hotkey = GlobalShortcut(
            keyCode: 17, modifiers: GlobalShortcut.control | GlobalShortcut.option, keyLabel: "T")
        model.selectedID = "app:preview-terminal"
        return model
    }

    static func write(_ view: NSView, to url: URL) throws {
        view.layoutSubtreeIfNeeded()
        // Allow hosted views to lay out and serial background icon loads to finish.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ConfigError.invalid("Could not allocate a native view preview.")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ConfigError.invalid("Could not encode the native view preview.")
        }
        try data.write(to: url, options: .atomic)
    }
}
