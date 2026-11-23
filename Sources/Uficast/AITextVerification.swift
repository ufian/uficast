import AppKit
import Carbon.HIToolbox
import UficastCore

/// Development-only native checks for AI text. Uses private pasteboards and fakes;
/// never runs a real AI command or reads the general clipboard.
@MainActor
enum AITextVerification {
    static func run() throws {
        try richTextRoundTrip()
        try panelControls()
        try coordinatorFlows()
        try reviewRegressions()
        try hotkeyDelivery()
    }

    /// A registered AI shortcut must reach `onAIAction`, press by press. The Carbon event is
    /// sent to the application target, so no key is typed and no privacy grant is involved.
    private static func hotkeyDelivery() throws {
        let service = HotkeyService()
        defer { service.stop() }
        let rewrite = GlobalShortcut(keyCode: 79, modifiers: GlobalShortcut.control | GlobalShortcut.option | GlobalShortcut.command, keyLabel: "F18")
        let translate = GlobalShortcut(keyCode: 80, modifiers: GlobalShortcut.control | GlobalShortcut.option | GlobalShortcut.command, keyLabel: "F19")
        var received: [AITextAction] = []
        service.onAIAction = { received.append($0) }
        service.configure(launcher: GlobalShortcut(keyCode: 64, modifiers: GlobalShortcut.control | GlobalShortcut.option | GlobalShortcut.command, keyLabel: "F17"),
                          ai: [.rewrite: rewrite, .translate: translate], appShortcuts: [:])
        try require(service.aiErrors.isEmpty, "AI shortcuts were not registered: \(service.aiErrors)")
        func send(_ kind: Int, id: UInt32) throws {
            var event: EventRef?
            try require(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kind), 0, EventAttributes(kEventAttributeNone), &event) == noErr, "event")
            var identity = EventHotKeyID(signature: 0x55464943, id: id)
            try require(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          MemoryLayout<EventHotKeyID>.size, &identity) == noErr, "parameter")
            _ = SendEventToEventTarget(event, GetApplicationEventTarget())
            ReleaseEvent(event)
        }
        try send(kEventHotKeyPressed, id: 1000)
        try send(kEventHotKeyReleased, id: 1000)
        try send(kEventHotKeyPressed, id: 1001)
        try send(kEventHotKeyReleased, id: 1001)
        try require(received == [.rewrite, .translate], "AI shortcut presses were not delivered: \(received)")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw ConfigError.invalid(message) }
    }

    static func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("dev.ufian.Uficast.verify.\(UUID().uuidString)"))
    }

    static func sample() -> NSAttributedString {
        let body = NSFont.systemFont(ofSize: 13), bold = NSFont.boldSystemFont(ofSize: 13)
        let text = NSMutableAttributedString(string: "Please ", attributes: [.font: body])
        text.append(NSAttributedString(string: "review", attributes: [.font: bold]))
        text.append(NSAttributedString(string: " the ", attributes: [.font: body]))
        text.append(NSAttributedString(string: "file", attributes: [.font: body, .link: URL(string: "https://example.com")!]))
        return text
    }

    static func isBold(_ text: NSAttributedString, word: String) -> Bool {
        let range = (text.string as NSString).range(of: word)
        guard range.location != NSNotFound,
              let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.bold)
    }

    private static func richTextRoundTrip() throws {
        let source = sample()
        let rich = RichTextBridge.split(source, isRich: true)
        try require(rich.styles.count == 2, "Expected bold and link styles, got \(rich.styles.count)")
        let encoded = SpanMarkup.encode(rich.segments)
        try require(encoded.hasMarkers, "Styled text must be marked")
        guard let decoded = SpanMarkup.decode(encoded.text, styleCount: rich.styles.count) else {
            throw ConfigError.invalid("Own markers must decode")
        }
        let joined = RichTextBridge.join(decoded, from: rich)
        try require(joined.string == source.string, "Round trip changed the text")
        try require(isBold(joined, word: "review"), "Bold run lost")
        let link = (joined.string as NSString).range(of: "file")
        try require((joined.attribute(.link, at: link.location, effectiveRange: nil) as? URL)?.absoluteString == "https://example.com",
                    "Link lost")

        let board = privatePasteboard()
        defer { board.releaseGlobally() }
        RichTextBridge.write(joined, rich: true, to: board)
        try require(board.types?.contains(.rtf) == true && board.types?.contains(.string) == true, "Rich write needs RTF and plain text")
        try require(RichTextBridge.isRich(board) && RichTextBridge.read(board)?.string == source.string, "Rich read failed")
        RichTextBridge.write(NSAttributedString(string: "plain"), rich: false, to: board)
        try require(board.types?.contains(.rtf) != true, "A plain source must not gain RTF")
        try require(!RichTextBridge.isRich(board) && RichTextBridge.read(board)?.string == "plain", "Plain read failed")
        board.clearContents()
        try require(RichTextBridge.read(board) == nil, "An empty pasteboard must read as nil")
        let plain = RichTextBridge.split(NSAttributedString(string: "a < b"), isRich: false)
        try require(plain.styles.isEmpty && !plain.isRich && SpanMarkup.encode(plain.segments).text == "a < b", "Plain split must stay unmarked")
    }

    private static func panelControls() throws {
        let panel = AITextPanelController()
        panel.presentsWindow = false
        var confirms = 0, cancels = 0, retries = 0
        panel.onConfirm = { _ in confirms += 1 }
        panel.onCancel = { cancels += 1 }
        panel.onRetry = { retries += 1 }
        panel.showWorking(action: .rewrite)
        try require(panel.hint == "Working…  ·  Esc Cancel" && panel.title == "Rewrite", "Working state")
        panel.performConfirm()
        try require(confirms == 0, "Enter while working must do nothing")
        panel.showResult(sample(), note: nil)
        try require(panel.hint == "↩ Copy  ·  Esc Cancel", "Copy hint")
        panel.performConfirm()
        try require(confirms == 1, "Enter on a result confirms once")
        panel.showWorking(action: .translate)
        panel.showResult(NSAttributedString(string: "Готово"), note: "Formatting could not be kept.")
        try require(panel.hint == "↩ Copy  ·  Esc Cancel" && panel.note == "Formatting could not be kept.", "Copy hint and note")
        panel.showFailure("Boom")
        try require(panel.hint == "↩ Retry  ·  Esc Close", "Failure hint")
        panel.performConfirm()
        try require(retries == 1 && confirms == 1, "Enter on a failure retries")
        panel.showMessage("Copy text first.")
        try require(panel.hint == "Esc Close", "Message hint")
        panel.performConfirm()
        try require(retries == 1 && confirms == 1, "Enter on a message does nothing")
        panel.showWorking(action: .rewrite)
        panel.showResult(sample(), note: nil)
        panel.performCancel()
        panel.performCancel()
        try require(cancels == 1, "Esc cancels once")
    }

    /// Scripted runner: answers in order after a delay; cancel makes a pending run throw.
    private actor FakeRunner: AITextRunning {
        private var answers: [Result<String, AITextError>]
        private let delay: Duration
        private var generation = 0
        private(set) var calls = 0
        private(set) var cancels = 0
        private(set) var prompts: [String] = []
        init(_ answers: [Result<String, AITextError>], delay: Duration = .milliseconds(50)) {
            self.answers = answers
            self.delay = delay
        }
        func run(command: String, prompt: String, timeout: Double) async throws -> String {
            calls += 1
            prompts.append(prompt)
            let started = generation
            let answer = answers.isEmpty ? .success("ok") : answers.removeFirst()
            try? await Task.sleep(for: delay)
            guard generation == started else { throw AITextError.cancelled }
            return try answer.get()
        }
        func cancel() { cancels += 1; generation += 1 }
    }

    private static func spin(_ seconds: Double = 2, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition(), Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
    }

    private static func make(_ runner: FakeRunner) -> (AITextCoordinator, AITextPanelController, NSPasteboard) {
        let panel = AITextPanelController()
        panel.presentsWindow = false
        let general = privatePasteboard()
        return (AITextCoordinator(panel: panel, runner: runner, general: general, timeout: 5), panel, general)
    }

    private static func coordinatorFlows() throws {
        let copy = "↩ Copy  ·  Esc Cancel"
        do { // Empty clipboard and an image-only clipboard never run the command.
            let runner = FakeRunner([])
            let (coordinator, panel, general) = make(runner)
            general.clearContents()
            coordinator.runFromClipboard(.rewrite)
            try require(panel.shownText == "Copy text first." && panel.hint == "Esc Close", "Empty clipboard message")
            general.clearContents()
            let pixel = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            general.setData(pixel?.tiffRepresentation ?? Data(), forType: .tiff)
            coordinator.runFromClipboard(.translate)
            try require(panel.shownText == "Copy text first.", "Image-only clipboard message")
            spin(0.2) { false }
            try require(Task.awaitValue { await runner.calls } == 0, "No command may run without text")
        }
        do { // Clipboard rewrite: Enter copies the result.
            let (coordinator, panel, general) = make(FakeRunner([.success("We were here.")]))
            general.clearContents()
            general.setString("we was here", forType: .string)
            coordinator.runFromClipboard(.rewrite)
            spin { panel.hint == copy }
            try require(panel.shownText == "We were here.", "Clipboard result shown")
            panel.performConfirm()
            try require(general.string(forType: .string) == "We were here." && !panel.isVisible, "Enter copies and closes")
        }
        do { // Esc while working cancels; the late result neither shows nor writes.
            let runner = FakeRunner([.success("late")], delay: .milliseconds(300))
            let (coordinator, panel, general) = make(runner)
            general.clearContents()
            general.setString("source", forType: .string)
            coordinator.runFromClipboard(.rewrite)
            panel.performCancel()
            spin(0.6) { false }
            try require(Task.awaitValue { await runner.cancels } >= 1, "Esc cancels the command")
            try require(!panel.isVisible && general.string(forType: .string) == "source", "Late result ignored")
        }
        do { // Failure, then an explicit retry.
            let runner = FakeRunner([.failure(.failed("Boom")), .success("second")])
            let (coordinator, panel, general) = make(runner)
            general.clearContents()
            general.setString("text", forType: .string)
            coordinator.runFromClipboard(.translate)
            spin { panel.hint == "↩ Retry  ·  Esc Close" }
            try require(panel.shownText == "Boom", "Failure text shown")
            panel.performConfirm()
            spin { panel.hint == copy }
            try require(panel.shownText == "second" && Task.awaitValue { await runner.calls } == 2, "Retry runs again")
        }
        do { // A link carries its own text: the clipboard is not read, Enter copies plain text.
            let runner = FakeRunner([.success("We were here.")])
            let (coordinator, panel, general) = make(runner)
            general.clearContents()
            general.setString("clipboard text", forType: .string)
            coordinator.runFromURL(URL(string: "uficast://rewrite?text=we%20was%20here")!)
            spin { panel.hint == copy }
            try require(panel.shownText == "We were here.", "Link result shown")
            let prompts = Task.awaitValue { await runner.prompts }
            try require(prompts.count == 1 && prompts[0].contains("we was here") && !prompts[0].contains("clipboard text"),
                        "The link's text, not the clipboard, must be sent")
            panel.performConfirm()
            try require(general.string(forType: .string) == "We were here." && general.types?.contains(.rtf) != true && !panel.isVisible,
                        "Enter copies the link's result as plain text")
        }
        do { // A link without text uses the clipboard, like the Shortcut's own fallback.
            let runner = FakeRunner([.success("Привет")])
            let (coordinator, panel, general) = make(runner)
            general.clearContents()
            general.setString("from clipboard", forType: .string)
            coordinator.runFromURL(URL(string: "uficast://translate")!)
            spin { panel.hint == copy }
            let prompts = Task.awaitValue { await runner.prompts }
            try require(panel.shownText == "Привет" && prompts.count == 1 && prompts[0].contains("from clipboard"),
                        "A link without text must use the clipboard")
        }
        do { // Overlong text is refused, an unknown link is ignored; neither runs the command.
            let runner = FakeRunner([])
            let (coordinator, panel, _) = make(runner)
            let long = String(repeating: "a", count: AITextURL.maximumTextLength + 1)
            coordinator.runFromURL(URL(string: "uficast://rewrite?text=\(long)")!)
            try require(panel.shownText.contains("too long") && panel.hint == "Esc Close", "Overlong text message")
            panel.dismiss()
            coordinator.runFromURL(URL(string: "uficast://launch?text=x")!)
            coordinator.runFromURL(URL(string: "https://rewrite?text=x")!)
            spin(0.2) { false }
            try require(!panel.isVisible && Task.awaitValue { await runner.calls } == 0, "Refused links must not run the command")
        }
        do { // Diagnostics: a link and a panel closed by lost focus are reported, a confirmed one is not.
            let runner = FakeRunner([.success("Done.")], delay: .milliseconds(300))
            let (coordinator, panel, general) = make(runner)
            var events: [String] = []
            coordinator.onEvent = { events.append($0) }
            general.clearContents()
            coordinator.runFromURL(URL(string: "uficast://rewrite?text=we%20was%20here")!)
            try require(events == ["Rewrite link received (11 characters)."], "A link must be reported once: \(events)")
            panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
            try require(events.count == 2 && events[1] == "The result panel closed because it lost focus." && !panel.isVisible,
                        "Losing focus while working must be reported and close the panel: \(events)")
            spin(0.6) { false }
            let confirmed = FakeRunner([.success("Done.")])
            let (second, secondPanel, _) = make(confirmed)
            var secondEvents: [String] = []
            second.onEvent = { secondEvents.append($0) }
            second.runFromURL(URL(string: "uficast://translate?text=hello")!)
            spin { secondPanel.hint == copy }
            secondPanel.performConfirm()
            secondPanel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
            try require(secondEvents == ["Translate link received (5 characters)."], "A confirmed panel must not report lost focus: \(secondEvents)")
            coordinator.runFromClipboard(.rewrite)
            try require(events.count == 2, "A clipboard request must not report a link")
        }
        do { // A rich clipboard keeps its bold run through the markers.
            let (coordinator, panel, general) = make(FakeRunner([.success("Kindly <s1>review</s1> the <s2>file</s2>")]))
            RichTextBridge.write(sample(), rich: true, to: general)
            coordinator.runFromClipboard(.rewrite)
            spin { panel.hint == copy }
            panel.performConfirm()
            guard let copied = RichTextBridge.read(general) else { throw ConfigError.invalid("Rich result was not copied") }
            try require(copied.string == "Kindly review the file" && isBold(copied, word: "review"), "Copied result keeps bold")
        }
        do { // Broken markers fall back to the base style with a note.
            let (coordinator, panel, general) = make(FakeRunner([.success("Kindly <s3>review</s3>")]))
            RichTextBridge.write(sample(), rich: true, to: general)
            coordinator.runFromClipboard(.rewrite)
            spin { panel.hint == copy }
            try require(panel.note == "Formatting could not be kept.", "Fallback note")
            panel.performConfirm()
            try require(general.string(forType: .string) == "Kindly review", "Fallback copies text without markers")
        }
    }
}

extension AITextVerification {
    /// Findings from the final review; each check failed before its fix.
    fileprivate static func reviewRegressions() throws {
        func check(_ condition: Bool, _ message: String) throws { if !condition { throw ConfigError.invalid(message) } }
        do { // An attachment-only selection (an image) is not text.
            let pixel = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let png = pixel.representation(using: .png, properties: [:])!.base64EncodedString()
            let board = privatePasteboard()
            defer { board.releaseGlobally() }
            board.clearContents()
            board.setData(Data("<img src=\"data:image/png;base64,\(png)\">".utf8), forType: .html)
            try check(RichTextBridge.read(board) == nil, "An image-only HTML selection must read as no text")
        }
        do { // An answer that is empty after cleaning is a failure, not an empty result.
            let panel = AITextPanelController()
            panel.presentsWindow = false
            let general = privatePasteboard()
            let coordinator = AITextCoordinator(panel: panel, runner: FakeRunnerForReview(answer: "<text></text>"), general: general,
                                                timeout: 5)
            general.clearContents()
            general.setString("text", forType: .string)
            coordinator.runFromClipboard(.rewrite)
            let deadline = Date().addingTimeInterval(2)
            while panel.hint == "Working…  ·  Esc Cancel", Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
            try check(panel.hint == "↩ Retry  ·  Esc Close" && panel.shownText == AITextError.emptyOutput.localizedDescription,
                      "An empty cleaned answer must be shown as a failure")
        }
        do { // Pasteboard HTML is UTF-8 even without a charset declaration.
            let board = privatePasteboard()
            defer { board.releaseGlobally() }
            board.clearContents()
            board.setData(Data("<p>Привет, мир</p>".utf8), forType: .html)
            try check(RichTextBridge.read(board)?.string.trimmingCharacters(in: .whitespacesAndNewlines) == "Привет, мир",
                      "HTML without a charset must decode as UTF-8")
        }
    }

    private actor FakeRunnerForReview: AITextRunning {
        let answer: String
        init(answer: String) { self.answer = answer }
        func run(command: String, prompt: String, timeout: Double) async throws -> String {
            try? await Task.sleep(for: .milliseconds(50))
            return answer
        }
        func cancel() {}
    }
}

private extension Task where Failure == Never {
    /// Reads an actor value from the verification's synchronous main-thread code.
    @MainActor static func awaitValue(_ body: @escaping @Sendable () async -> Success) -> Success {
        var value: Success?
        Task<Void, Never> { @MainActor in value = await body() }
        while value == nil { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        return value!
    }
}

