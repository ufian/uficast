import AppKit
import SwiftUI
import UficastCore

/// General → AI Text: the editable command, clipboard shortcuts and the Shortcuts that open requests here.
struct AITextSettings: View {
    @ObservedObject var model: SettingsModel
    @State private var draft = ""

    var body: some View {
        SettingsCard(title: "AI Text", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Command", text: $draft).font(.system(.callout, design: .monospaced)).textFieldStyle(.roundedBorder)
                        .onSubmit { model.onSetAICommand?(draft) }
                    Button("Apply") { model.onSetAICommand?(draft) }
                        .disabled(draft == model.configuration.aiText.command)
                    Button { model.onSetAICommand?(AITextPreferences.defaultCommand) } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset to Default").accessibilityLabel("Reset command to default")
                    .disabled(model.configuration.aiText.command == AITextPreferences.defaultCommand)
                    InfoButton(text: "The command gets the prompt on stdin and must print only the answer, for example claude -p or codex. It runs in your login shell; change the model or the program here.\n\nThe text is sent to the program the command runs (Anthropic for claude). Uficast stores no text; the program may keep data under its own settings.")
                }.disabled(model.isBusy || model.isReadOnly)
                HStack(spacing: 14) {
                    ForEach(AITextAction.allCases, id: \.self) { action in hotkey(action) }
                    Spacer(minLength: 0)
                    InfoButton(text: "Clipboard shortcuts: copy text, press the shortcut, check the result, then ↩ copies it for pasting. Esc cancels. This works in any app.")
                }.disabled(model.isBusy || model.isReadOnly)
                ForEach(AITextAction.allCases, id: \.self) { action in
                    if let error = model.aiHotkeyErrors[action] { Text(error).font(.caption).foregroundStyle(.red) }
                }
                HStack(spacing: 8) {
                    ForEach(AITextAction.allCases, id: \.self) { action in
                        Button("Create \(action.title) Shortcut") { model.onCreateShortcut?(action) }
                    }
                    Spacer(minLength: 0)
                    InfoButton(text: "Opens a new shortcut in the Shortcuts app, copies the script for it and lists the steps. The shortcut uses the selected text where the app offers it, otherwise the clipboard, and shows the result here; ↩ copies it. Shortcuts refuses generated files, so you build it by hand.")
                }
            }
        }
        .sheet(isPresented: Binding(get: { model.shortcutGuide != nil }, set: { if !$0 { model.shortcutGuide = nil } })) {
            if let action = model.shortcutGuide { ShortcutGuideSheet(action: action) { model.shortcutGuide = nil } }
        }
        .onAppear { draft = model.configuration.aiText.command }
        .onChange(of: model.configuration.aiText.command) { _, command in draft = command }
    }

    private func hotkey(_ action: AITextAction) -> some View {
        HStack(spacing: 6) {
            Text(action.title)
            ShortcutRecorder(shortcut: model.configuration.aiText.hotkey(for: action),
                accessibilityName: "Record \(action.title.lowercased()) from clipboard shortcut",
                onCapture: { model.onSetAIHotkey?(action, $0) },
                onBegin: { model.onBeginShortcutRecording?() },
                onEnd: { model.onEndShortcutRecording?() })
                .frame(width: 118)
            if model.configuration.aiText.hotkey(for: action) != nil {
                Button { model.onSetAIHotkey?(action, nil) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove shortcut")
                .accessibilityLabel("Remove \(action.title.lowercased()) from clipboard shortcut")
            }
        }
    }
}

/// Steps for building the shortcut by hand, since Shortcuts refuses to import unsigned files.
struct ShortcutGuideSheet: View {
    let action: AITextAction
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build “\(ShortcutGuide.shortcutName(for: action))”").font(.title3.bold())
            Text("Shortcuts is open with an empty shortcut, and the script is on your clipboard.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(Array(ShortcutGuide.steps(for: action).enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1)").font(.callout.weight(.semibold)).foregroundStyle(.secondary).frame(width: 14)
                    Text(step).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(ShortcutGuide.script(for: action))
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("Copy Script") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ShortcutGuide.script(for: action), forType: .string)
                }
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
