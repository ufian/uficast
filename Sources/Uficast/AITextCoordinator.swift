import AppKit
import UficastCore

/// Serves the AI text entry points: the clipboard hotkeys and `uficast://` links opened by a
/// Shortcut. Both show the result first; Enter copies it. Exactly one request is active;
/// anything that finishes for an older request is ignored.
@MainActor
final class AITextCoordinator {
    private struct Request {
        var id: UUID
        let action: AITextAction
        let source: RichText
    }

    var command = AITextPreferences.defaultCommand
    /// Called before the panel appears, so the launcher can hide.
    var beforePresent: (() -> Void)?
    /// Short, text-free notes about what happened (a link arrived, the panel lost focus), so
    /// Recent Runs can show why a request seemed to do nothing.
    var onEvent: ((String) -> Void)?

    private let panel: AITextPanelController
    private let runner: AITextRunning
    private let general: NSPasteboard
    private let timeout: Double
    private var current: Request?

    init(panel: AITextPanelController, runner: AITextRunning, general: NSPasteboard = .general, timeout: Double = 60) {
        self.panel = panel
        self.runner = runner
        self.general = general
        self.timeout = timeout
        panel.onConfirm = { [weak self] in self?.confirm($0) }
        panel.onCancel = { [weak self] in self?.cancelCurrent() }
        panel.onRetry = { [weak self] in self?.retry() }
        panel.onLostFocus = { [weak self] in self?.onEvent?("The result panel closed because it lost focus.") }
    }

    func runFromClipboard(_ action: AITextAction) {
        guard let text = RichTextBridge.read(general) else {
            show("Copy text first.")
            return
        }
        start(action, text: text, rich: RichTextBridge.isRich(general))
    }

    /// A Shortcut passes the selection (or the clipboard, which the Shortcut falls back to)
    /// in the link. A link without text uses the clipboard here as well; anything that is not
    /// one of our links is ignored.
    func runFromURL(_ url: URL) {
        guard let request = AITextURL.parse(url) else { return }
        onEvent?("\(request.action.title) link received (\(request.text?.count ?? 0) characters).")
        guard !request.isTooLong else {
            show("The text is too long (the limit is \(AITextURL.maximumTextLength.formatted()) characters).")
            return
        }
        guard let text = request.text else { runFromClipboard(request.action); return }
        start(request.action, text: NSAttributedString(string: text), rich: false)
    }

    private func show(_ message: String) {
        cancelCurrent()
        beforePresent?()
        panel.showMessage(message)
    }

    private func start(_ action: AITextAction, text: NSAttributedString, rich: Bool) {
        cancelCurrent()
        current = Request(id: UUID(), action: action, source: RichTextBridge.split(text, isRich: rich))
        beforePresent?()
        panel.showWorking(action: action)
        launch()
    }

    private func retry() {
        guard var request = current else { return }
        request.id = UUID()
        current = request
        panel.showWorking(action: request.action)
        launch()
    }

    private func launch() {
        guard let request = current else { return }
        let encoded = SpanMarkup.encode(request.source.segments)
        let prompt = AITextPrompt.build(action: request.action, text: encoded.text, hasMarkers: encoded.hasMarkers)
        let styleCount = encoded.hasMarkers ? request.source.styles.count : 0
        let (runner, command, timeout, id) = (self.runner, self.command, self.timeout, request.id)
        Task { [weak self] in
            let outcome: Result<String, Error>
            do { outcome = .success(try await runner.run(command: command, prompt: prompt, timeout: timeout)) }
            catch { outcome = .failure(error) }
            switch outcome {
            case .success(let output): self?.finish(id, output: output, styleCount: styleCount)
            case .failure(let error): self?.fail(id, error)
            }
        }
    }

    private func finish(_ id: UUID, output: String, styleCount: Int) {
        guard let request = current, request.id == id else { return }
        let cleaned = AITextPrompt.clean(output)
        var note: String?
        let segments: [StyledSegment]
        if let decoded = SpanMarkup.decode(cleaned, styleCount: styleCount) {
            segments = decoded
        } else {
            segments = [StyledSegment(text: Self.withoutMarkers(cleaned), style: nil)]
            note = "Formatting could not be kept."
        }
        // Never offer an empty result: Enter would put nothing on the clipboard.
        guard segments.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            panel.showFailure(AITextError.emptyOutput.localizedDescription)
            return
        }
        panel.showResult(RichTextBridge.join(segments, from: request.source), note: note)
    }

    private func fail(_ id: UUID, _ error: Error) {
        guard current?.id == id, (error as? AITextError) != .cancelled else { return }
        panel.showFailure(error.localizedDescription)
    }

    private func confirm(_ result: NSAttributedString) {
        guard let request = current else { return }
        RichTextBridge.write(result, rich: request.source.isRich, to: general)
        current = nil
        panel.dismiss()
    }

    private func cancelCurrent() {
        guard current != nil else { return }
        current = nil
        panel.dismiss()
        Task { [runner] in await runner.cancel() }
    }

    /// Base-style fallback: drop every marker tag and restore escaped characters.
    private static func withoutMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: #"</?s[0-9]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
