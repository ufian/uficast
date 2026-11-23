import AppKit
import SwiftUI
import UficastCore

@MainActor
final class SettingsModel: ObservableObject {
    @Published var configuration = Configuration()
    @Published var section = "Commands"
    @Published var catalogEntries: [LauncherEntry] = []
    @Published var query = ""
    @Published var filter = "All"
    @Published var searchFocusRequest = 0
    @Published var selectedID: String?
    @Published var status = "Loading settings…"
    @Published var lastActionStatus = "No recent actions."
    @Published var shortcutStatus = ""
    @Published var isBusy = true
    @Published var isReadOnly = false
    @Published var scriptDraft: ScriptCommand?
    @Published var saveRevision = 0
    var onSave: ((Configuration) -> Void)?
    var onRefresh: (() -> Void)?
    var onRetryShortcut: (() -> Void)?
    var onAddApp: (() -> Void)?
    var onAddScriptFolder: (() -> Void)?
    var onRefreshScripts: (() -> Void)?
    var onImport: (() -> Void)?
    var onExport: (() -> Void)?
    var onRestore: (() -> Void)?
    @Published var recentRuns: [String] = []
    @Published var activeScripts: [String: String] = [:]
    var onCancelScript: ((String) -> Void)?
    @Published var keyboardStatus = "Caps Lock remapping is disabled."
    @Published var isKeyboardBusy = false
    @Published var loginItemRegistered = false
    @Published var loginItemStatus = "Start at login is disabled."
    @Published var isLoginItemBusy = false
    var onSetCapsLock: ((Bool) -> Void)?
    var onCheckKeyboard: (() -> Void)?
    var onSetLoginItem: ((Bool) -> Void)?
    @Published var keepAwakeActive = false
    @Published var keepAwakeStatus = "Automatic idle sleep is allowed."
    @Published var isKeepAwakeBusy = false
    var onSetKeepAwake: ((Bool) -> Void)?
    var onKeepAwakeFor: ((TimeInterval) -> Void)?
    @Published var hotkeyErrors: [String: String] = [:]
    var onSetLauncherHotkey: ((GlobalShortcut?) -> Void)?
    var onSetAICommand: ((String) -> Void)?
    var onSetAIHotkey: ((AITextAction, GlobalShortcut?) -> Void)?
    var onCreateShortcut: ((AITextAction) -> Void)?
    @Published var shortcutGuide: AITextAction?
    @Published var aiHotkeyErrors: [AITextAction: String] = [:]
    var onBeginShortcutRecording: (() -> Void)?
    var onEndShortcutRecording: (() -> Void)?

    var entries: [LauncherEntry] {
        let queries = KeyboardLayoutSearch.variants(query)
        return configuration.entries(catalog: catalogEntries).filter { entry in
            guard filter == "All" || (filter == "Apps" ? entry.kind == .application : entry.kind == .script) else { return false }
            if queries == [""] { return true }
            let name = SearchText.normalize(entry.name)
            let alias = SearchText.normalize(entry.alias ?? "")
            return queries.contains { name.contains($0) || alias.contains($0) }
        }.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var selected: LauncherEntry? {
        configuration.entries(catalog: catalogEntries).first { $0.id == selectedID }
    }

    @discardableResult
    func saveAlias(_ value: String, for entry: LauncherEntry) -> Bool {
        guard !isBusy, !isReadOnly, let onSave else { return false }
        let alias = value.isEmpty ? nil : value
        var updated = configuration
        if entry.kind == .application {
            var app = applicationOverride(entry)
            app.alias = alias
            updated.applications[entry.id] = app
        } else if let index = updated.scripts.firstIndex(where: { $0.entry.id == entry.id }) {
            updated.scripts[index].alias = alias
        }
        do { _ = try updated.validated() }
        catch { status = error.localizedDescription; return false }
        onSave(updated)
        return true
    }

    func setEnabled(_ enabled: Bool, for entry: LauncherEntry) {
        var updated = configuration
        if entry.kind == .application {
            var app = applicationOverride(entry)
            app.isEnabled = enabled
            updated.applications[entry.id] = app
        } else if let index = updated.scripts.firstIndex(where: { $0.entry.id == entry.id }) {
            updated.scripts[index].isEnabled = enabled
        }
        onSave?(updated)
    }

    func saveShortcut(_ shortcut: GlobalShortcut?, for entry: LauncherEntry) {
        var config = configuration
        var app = applicationOverride(entry)
        app.hotkey = shortcut
        config.applications[entry.id] = app
        onSave?(config)
    }

    func removeScriptFolder(_ path: String) {
        var config = configuration
        config.scriptDirectories.removeAll { $0 == path }
        config.scripts.removeAll { $0.sourceDirectory == path }
        onSave?(config)
    }

    private func applicationOverride(_ entry: LauncherEntry) -> AppOverride {
        AppOverride(alias: entry.alias, isEnabled: entry.isEnabled,
                    lastKnownName: entry.name, fallbackPath: entry.fileURL.path, hotkey: configuration.applications[entry.id]?.hotkey)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(model: SettingsModel) {
        let window = SettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Uficast Settings"
        window.minSize = NSSize(width: 820, height: 540)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        super.init(window: window)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func renderPreview(to url: URL) throws {
        guard let view = window?.contentView else { return }
        try ViewPreview.write(view, to: url)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var icons = IconStore()
    @State private var roots = ""
    @State private var showRuns = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                sectionButton("General", icon: "gearshape")
                sectionButton("Commands", icon: "square.grid.2x2")
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            Divider()
            if model.section == "General" { general } else { commands }
            Divider()
            HStack(spacing: 8) {
                if model.isBusy { ProgressView().controlSize(.small) }
                Text(model.status).font(.caption).lineLimit(1).truncationMode(.tail)
                    .help(model.status).textSelection(.enabled)
                Spacer()
                Button { showRuns.toggle() } label: { Label("Recent Runs", systemImage: "clock.arrow.circlepath") }
                    .controlSize(.small)
                    .popover(isPresented: $showRuns, arrowEdge: .top) { recentRuns }
            }.padding(.horizontal, 16).padding(.vertical, 9)
        }
        .onAppear { loadDrafts() }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.configuration) { _, _ in loadDrafts() }
        .sheet(item: $model.scriptDraft) { draft in ScriptEditor(model: model, script: draft) }
    }

    private func sectionButton(_ title: String, icon: String) -> some View {
        Button { model.section = title } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(model.section == title ? Color.primary.opacity(0.09) : .clear, in: Capsule())
            .contentShape(Capsule())
        }.buttonStyle(.plain)
    }

    private var commands: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                TextField("Search…", text: $model.query).textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .task(id: model.searchFocusRequest) {
                        if model.searchFocusRequest > 0 { searchFocused = true }
                    }
                Picker("Type", selection: $model.filter) {
                    ForEach(["All", "Apps", "Scripts"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 250)
                Menu {
                    Button("Add Script Folder…") { model.onAddScriptFolder?() }
                    Button("Add Script…") { model.scriptDraft = ScriptCommand(name: "New Script", path: "", interpreter: "/bin/zsh") }
                    Button("Add Application…") { model.onAddApp?() }
                } label: { Image(systemName: "plus") }
                    .disabled(model.isBusy || model.isReadOnly)
            }.padding(16)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Script Folders", systemImage: "folder")
                    Text("\(model.configuration.scriptDirectories.count)").foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Folder…") { model.onAddScriptFolder?() }
                    Button("Refresh Scripts") { model.onRefreshScripts?() }
                        .disabled(model.configuration.scriptDirectories.isEmpty)
                }
                if !model.configuration.scriptDirectories.isEmpty {
                    DisclosureGroup("Connected folders") {
                        ForEach(model.configuration.scriptDirectories, id: \.self) { path in
                            HStack {
                                Text(path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                                Spacer()
                                Button { model.removeScriptFolder(path) } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.borderless)
                                    .help("Disconnect folder and remove its commands. Script files are kept.")
                                    .accessibilityLabel("Disconnect script folder \(path)")
                            }.font(.caption)
                        }
                    }
                }
            }.padding(.horizontal, 16).padding(.vertical, 10)
                .disabled(model.isBusy || model.isReadOnly)
            Divider()
            Table(model.entries, selection: $model.selectedID) {
                TableColumn("Name") { entry in
                    HStack(spacing: 12) {
                        if entry.kind == .application {
                            Image(nsImage: icons.icon(for: entry.fileURL) ?? NSImage()).resizable().scaledToFit().frame(width: 24, height: 24)
                        } else { Image(systemName: "terminal.fill").frame(width: 24).foregroundStyle(.secondary) }
                        Text(entry.name).lineLimit(1)
                    }.padding(.vertical, 5)
                }.width(min: 230, ideal: 340)
                TableColumn("Type") { Text($0.kind == .application ? "Application" : "Script").foregroundStyle(.secondary) }
                    .width(min: 90, ideal: 110)
                TableColumn("Alias") { entry in
                    AliasEditor(entry: entry, onCommit: { model.saveAlias($0, for: entry) })
                        .frame(height: 24).disabled(model.isBusy || model.isReadOnly)
                }
                    .width(min: 100, ideal: 150)
                TableColumn("Hotkey") { entry in
                    if entry.kind == .application {
                        shortcutControl(for: entry, inline: true)
                    } else { Text("—").foregroundStyle(.secondary) }
                }.width(min: 110, ideal: 160)
                TableColumn("Enabled") { entry in
                    Toggle("Enabled", isOn: Binding(get: { entry.isEnabled }, set: { model.setEnabled($0, for: entry) }))
                        .labelsHidden().toggleStyle(.checkbox).disabled(model.isBusy || model.isReadOnly)
                }.width(75)
            }
            .overlay {
                if model.entries.isEmpty { ContentUnavailableView("No matching commands", systemImage: "magnifyingglass") }
            }
            if let selected = model.selected {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Text(selected.name).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text("Alias").foregroundStyle(.secondary)
                    AliasEditor(entry: selected, onCommit: { model.saveAlias($0, for: selected) })
                        .frame(width: 150, height: 24).disabled(model.isBusy || model.isReadOnly)
                    if selected.kind == .script {
                        Button("Edit…") { model.scriptDraft = model.configuration.scripts.first { $0.entry.id == selected.id } }
                            .disabled(model.isBusy || model.isReadOnly)
                        Button("Delete", role: .destructive) {
                            var config = model.configuration
                            config.scripts.removeAll { $0.entry.id == selected.id }
                            model.onSave?(config)
                        }.disabled(model.isBusy || model.isReadOnly || selectedScriptIsFolderManaged)
                    }
                }
                if selectedScriptIsFolderManaged {
                    Text("Connected folder script. Disable to hide it; disconnect the folder to remove its commands. Files stay in place.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if selected.kind == .application {
                    HStack {
                        Text("Show / Hide").foregroundStyle(.secondary)
                        shortcutControl(for: selected).frame(width: 180)
                        Text("Brings the app forward; press again while active to hide.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = model.hotkeyErrors[selected.id] { Text(error).font(.caption).foregroundStyle(.red) }
                }
                }.padding(16)
            }
        }
    }

    private var selectedScriptIsFolderManaged: Bool {
        model.configuration.scripts.contains { $0.entry.id == model.selectedID && $0.sourceDirectory != nil }
    }

    private func shortcutControl(for entry: LauncherEntry, inline: Bool = false) -> some View {
        HStack(spacing: 4) {
            ShortcutRecorder(shortcut: model.configuration.applications[entry.id]?.hotkey,
                requiresDoubleClick: inline,
                onCapture: { model.saveShortcut($0, for: entry) },
                onBegin: { model.onBeginShortcutRecording?() },
                onEnd: { model.onEndShortcutRecording?() })
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.configuration.applications[entry.id]?.hotkey != nil {
                Button { model.saveShortcut(nil, for: entry) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove hotkey")
                .accessibilityLabel("Remove hotkey for \(entry.name)")
            }
        }.disabled(model.isBusy || model.isReadOnly)
    }

    /// Two columns of cards that fit the window; it only scrolls if the window is made very small.
    private var general: some View {
        ViewThatFits(in: .vertical) {
            generalColumns
            ScrollView { generalColumns }
        }
    }

    private var generalColumns: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                launcherCard
                MenuBarClockSettings(model: model)
                powerCard
            }.frame(maxWidth: .infinity)
            VStack(spacing: 14) {
                AITextSettings(model: model)
                foldersCard
                configurationCard
            }.frame(maxWidth: .infinity)
        }.padding(16)
    }

    private var launcherCard: some View {
        SettingsCard(title: "Launcher", systemImage: "command") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Start at login", isOn: Binding(get: { model.loginItemRegistered }, set: { model.onSetLoginItem?($0) }))
                        .disabled(model.isLoginItemBusy).help(model.loginItemStatus)
                    Spacer()
                    Button("Login Items…") { LoginItemService.openSettings() }
                }
                if !model.loginItemStatus.hasPrefix("Start at login is") {
                    Text(model.loginItemStatus).font(.caption).foregroundStyle(.orange)
                }
                Divider()
                HStack(spacing: 8) {
                    Text("Shortcut")
                    ShortcutRecorder(shortcut: model.configuration.effectiveLauncherHotkey,
                        accessibilityName: "Record launcher shortcut",
                        onCapture: { model.onSetLauncherHotkey?($0) },
                        onBegin: { model.onBeginShortcutRecording?() },
                        onEnd: { model.onEndShortcutRecording?() })
                        .frame(width: 150)
                    if model.configuration.launcherHotkey != nil {
                        Button { model.onSetLauncherHotkey?(nil) } label: { Image(systemName: "arrow.counterclockwise") }
                            .help("Reset to \(GlobalShortcut.launcher.display)")
                            .accessibilityLabel("Reset launcher shortcut to \(GlobalShortcut.launcher.display)")
                    }
                    Spacer()
                    Menu {
                        Button("Retry Registration") { model.onRetryShortcut?() }
                        Button("Open Keyboard Shortcuts…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") { NSWorkspace.shared.open(url) }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Shortcut actions")
                    InfoButton(text: "Click the field, then press a new shortcut with ⌘, ⌃ or ⌥. Escape cancels; Delete restores \(GlobalShortcut.launcher.display). Left and right modifier keys both work.\n\nIf Spotlight or Raycast uses the same shortcut, release it in their settings; Uficast does not change those assignments. No Accessibility or Input Monitoring access is required.")
                }.disabled(model.isBusy || model.isReadOnly)
                Text(model.shortcutStatus).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(model.shortcutStatus)
            }
        }
    }

    private var powerCard: some View {
        SettingsCard(title: "Power & Keyboard", systemImage: "bolt.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Toggle("Keep Mac awake", isOn: Binding(get: { model.keepAwakeActive }, set: { model.onSetKeepAwake?($0) }))
                    Spacer()
                    Button("30 min") { model.onKeepAwakeFor?(1800) }
                    Button("1 hour") { model.onKeepAwakeFor?(3600) }
                    Button("Until stopped") { model.onSetKeepAwake?(true) }
                    InfoButton(text: "Keeps the display and Mac awake while active. Remembers the last mode on relaunch; timed sessions keep their original end time.")
                }.disabled(model.isKeepAwakeBusy)
                Text(model.keepAwakeStatus).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Divider()
                HStack(spacing: 8) {
                    Toggle("Map Caps Lock to F19", isOn: Binding(get: { model.configuration.capsLockToF19Enabled }, set: { model.onSetCapsLock?($0) }))
                        .disabled(model.isBusy || model.isReadOnly || model.isKeyboardBusy)
                    Spacer()
                    Button("Check Mapping") { model.onCheckKeyboard?() }.disabled(model.isKeyboardBusy)
                    InfoButton(text: "For each keyboard, set Caps Lock to Caps Lock in Modifier Keys first. Then assign F19 in Input Sources. Keep Uficast running; quitting restores its mapping.")
                }
                Text(model.keyboardStatus).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(model.keyboardStatus)
            }
        }
    }

    private var foldersCard: some View {
        SettingsCard(title: "Application Folders", systemImage: "folder") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $roots).font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden).padding(4).frame(height: 62)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                HStack(spacing: 8) {
                    Button("Save Folders") {
                        var config = model.configuration
                        config.applicationRoots = roots.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        model.onSave?(config)
                    }.disabled(model.isBusy || model.isReadOnly)
                    Button("Refresh Applications") { model.onRefresh?() }
                    Spacer()
                    InfoButton(text: "One folder or application path per line. Paths may start with ~/.")
                }
            }
        }
    }

    private var configurationCard: some View {
        SettingsCard(title: "Configuration", systemImage: "externaldrive") {
            HStack(spacing: 8) {
                Button("Import…") { model.onImport?() }.disabled(model.isReadOnly)
                Button("Export…") { model.onExport?() }
                Button("Restore Backup") { model.onRestore?() }
                Spacer()
                InfoButton(text: "Stored locally in ~/Library/Application Support/Uficast. Imports retain file paths; missing files must be located on this Mac.")
            }.disabled(model.isBusy)
        }
    }

    private var recentRuns: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Runs").font(.headline)
            Text(model.lastActionStatus).font(.caption).textSelection(.enabled)
            ForEach(model.activeScripts.keys.sorted(), id: \.self) { id in
                HStack {
                    Text("Running: \(model.activeScripts[id] ?? "Script")")
                    Button("Cancel") { model.onCancelScript?(id) }
                }
            }
            if model.recentRuns.isEmpty { Text("No runs yet.").foregroundStyle(.secondary) }
            ForEach(Array(model.recentRuns.enumerated()), id: \.offset) { _, run in
                Text(run).font(.caption).textSelection(.enabled).lineLimit(3)
            }
        }
        .padding(14).frame(width: 440, alignment: .leading)
    }

    private func loadDrafts() {
        roots = model.configuration.applicationRoots.joined(separator: "\n")
    }
}
