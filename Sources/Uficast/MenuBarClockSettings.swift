import SwiftUI
import UficastCore

struct MenuBarClockSettings: View {
    @ObservedObject var model: SettingsModel
    @State private var format = ""

    var body: some View {
        SettingsCard(title: "Menu Bar Clock", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Toggle("Show clock", isOn: Binding(
                        get: { model.configuration.menuBarClock.isEnabled },
                        set: { value in save { $0.isEnabled = value } }))
                        .help("Show date and time in the Uficast button.")
                    Toggle("Show icon", isOn: Binding(
                        get: { model.configuration.menuBarClock.showsIcon },
                        set: { value in save { $0.showsIcon = value } }))
                        .help("Show a calendar icon with today's date beside the clock.")
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(preview(context.date)).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                    }
                    InfoButton(text: "Click the Uficast button to browse months. The calendar does not read events or accounts.\n\nFormat: EEE = weekday · HH = 24-hour · h = 12-hour · mm = minutes · ss = seconds · a = AM/PM. Quote literal text with single quotes.")
                }
                HStack(spacing: 8) {
                    TextField("EEE HH:mm:ss", text: $format).textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                        .onSubmit { saveFormat() }
                    Button("Apply") { saveFormat() }
                        .disabled(format == model.configuration.menuBarClock.dateFormat)
                    Button("Reset") { format = MenuBarClockPreferences().dateFormat; saveFormat() }
                }
            }
            .disabled(model.isBusy || model.isReadOnly)
        }
        .onAppear { format = model.configuration.menuBarClock.dateFormat }
        .onChange(of: model.configuration.menuBarClock.dateFormat) { _, value in format = value }
    }

    private func preview(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = String(format.prefix(128))
        return String(formatter.string(from: date).prefix(100))
    }

    private func save(_ change: (inout MenuBarClockPreferences) -> Void) {
        var config = model.configuration
        change(&config.menuBarClock)
        do { try config.menuBarClock.validate(); model.onSave?(config) }
        catch { model.status = error.localizedDescription }
    }

    private func saveFormat() { save { $0.dateFormat = format } }
}
