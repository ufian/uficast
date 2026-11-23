import AppKit
import UficastCore

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func performClose(_ sender: Any?) { (delegate as? LauncherPanelController)?.dismiss() }
}

@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let panel: LauncherPanel
    private let field = NSTextField()
    private let table = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "Discovering applications…")
    private let icons = IconStore()
    private static let defaultHint = "↑↓ Select  ·  ↩ Open  ·  Tab Argument  ·  Esc Close"
    private static let calculatorHint = "↑↓ Select  ·  ↩ Copy Result  ·  Tab Edit  ·  Esc Close"
    private static let pullRequestHint = "↑↓ Select  ·  ↩ Open  ·  Esc Back"
    private static let pullRequestLoadingHint = "Loading pull requests…  ·  Esc Back"
    private let hint = NSTextField(labelWithString: LauncherPanelController.defaultHint)
    private let token = NSButton()
    private let argumentScroll = ArgumentScrollView()
    private let argumentInput = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 38))
    private let placeholder = ClickThroughLabel(labelWithString: "")
    private let settingsButton = NSButton()
    private let failureBox = NSStackView()
    private let failureLabel = NSTextField(wrappingLabelWithString: "")
    private let editInputButton = NSButton(title: "Edit Input", target: nil, action: nil)
    private var failureHeight: NSLayoutConstraint!
    /// The search field starts at the panel edge; in pull-request mode it starts after the token.
    private var fieldLeading: NSLayoutConstraint!
    private var fieldLeadingAfterToken: NSLayoutConstraint!
    private var activeRunID: UUID?
    private var latestRunID: UUID?
    private var lastFailure: (command: ScriptCommand, argument: String?, message: String)?
    private var argumentCommand: ScriptCommand?
    private var previousQuery = ""
    private var pullRequestMode = false
    private var pullRequests: [PullRequest] = []
    /// The latest pull-request load; nil when nothing is pending.
    private var pullRequestLoadID: UUID?
    /// Opens a pull request in the browser; the native check injects a fake.
    var openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    private var isDismissing = false
    private var index = SearchIndex()
    private var results: [LauncherEntry] = []
    /// Launch counts that order the empty search and break ties between equal
    /// matches. The owner of the controller persists them through `onUsageChange`.
    var usage: [String: UsageRecord] = [:] {
        didSet { if usage != oldValue { onUsageChange?(usage) } }
    }
    var onUsageChange: (([String: UsageRecord]) -> Void)?
    /// Remembered calculations and the unfinished formula. The owner of the
    /// controller persists it through `onCalculatorChange`.
    var calculator = CalculatorState() {
        didSet { if calculator != oldValue { onCalculatorChange?(calculator) } }
    }
    var onCalculatorChange: ((CalculatorState) -> Void)?
    var pasteboard = NSPasteboard.general
    var onSelect: ((LauncherEntry) -> Void)?
    var onArgumentSelection: ((LauncherEntry) -> Void)?
    var onArgumentSubmit: ((String, String) -> Void)?
    var onOpenSettings: (() -> Void)?
    var beforeShow: (() -> Void)?
    private var previousApplication: NSRunningApplication?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override init() {
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 470),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        super.init()
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.title = "Uficast Launcher"
        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true
        panel.contentView = background

        field.font = .systemFont(ofSize: 26)
        field.placeholderString = "Search applications and commands…"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.setAccessibilityLabel("Search applications and commands")
        let line = NSBox()
        line.boxType = .separator
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        table.backgroundColor = .clear
        table.headerView = nil
        table.rowHeight = 56
        table.intercellSpacing = NSSize(width: 0, height: 4)
        table.style = .plain
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result")))
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(activateSelected)
        table.setAccessibilityLabel("Search results")
        scroll.documentView = table
        emptyLabel.textColor = .secondaryLabelColor
        token.target = self
        token.action = #selector(returnToSearch)
        token.bezelStyle = .regularSquare
        token.isBordered = false
        token.font = .systemFont(ofSize: 25, weight: .regular)
        token.contentTintColor = .labelColor
        token.isHidden = true
        argumentScroll.documentView = argumentInput
        argumentScroll.drawsBackground = false
        argumentScroll.contentView.drawsBackground = false
        argumentScroll.wantsLayer = true
        argumentScroll.layer?.cornerRadius = 8
        argumentScroll.layer?.masksToBounds = true
        argumentScroll.isHidden = true
        argumentInput.isRichText = false
        argumentInput.importsGraphics = false
        argumentInput.allowsUndo = true
        argumentInput.font = .systemFont(ofSize: 25)
        argumentInput.textColor = .labelColor
        argumentInput.drawsBackground = false
        argumentInput.textContainerInset = NSSize(width: 10, height: 3)
        argumentInput.textContainer?.lineFragmentPadding = 0
        argumentInput.isVerticallyResizable = true
        argumentInput.isHorizontallyResizable = false
        argumentInput.autoresizingMask = [.width]
        argumentInput.textContainer?.widthTracksTextView = true
        argumentInput.isAutomaticQuoteSubstitutionEnabled = false
        argumentInput.isAutomaticDashSubstitutionEnabled = false
        argumentInput.isAutomaticTextReplacementEnabled = false
        argumentInput.isAutomaticSpellingCorrectionEnabled = false
        argumentInput.delegate = self
        placeholder.font = .systemFont(ofSize: 25)
        placeholder.textColor = .placeholderTextColor
        placeholder.isHidden = true
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byTruncatingTail
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Open Settings")
        settingsButton.title = settingsButton.image == nil ? "Settings" : ""
        settingsButton.isBordered = false
        settingsButton.target = self
        settingsButton.action = #selector(openSettingsFromLauncher)
        settingsButton.toolTip = "Open Settings (⌘,)"
        settingsButton.setAccessibilityLabel("Open Settings")
        failureBox.orientation = .vertical
        failureBox.alignment = .leading
        failureBox.spacing = 8
        failureBox.detachesHiddenViews = true
        failureLabel.font = .systemFont(ofSize: 12)
        failureLabel.textColor = .systemRed
        failureLabel.maximumNumberOfLines = 3
        failureLabel.lineBreakMode = .byTruncatingTail
        failureLabel.isSelectable = true
        editInputButton.target = self
        editInputButton.action = #selector(editFailedInput)
        failureBox.addArrangedSubview(failureLabel)
        failureBox.addArrangedSubview(editInputButton)
        failureLabel.isHidden = true
        editInputButton.isHidden = true
        failureBox.isHidden = true
        for view in [field, line, scroll, emptyLabel, hint, token, argumentScroll, placeholder, settingsButton, failureBox] {
            view.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(view)
        }
        NSLayoutConstraint.activate([
            field.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            field.topAnchor.constraint(equalTo: background.topAnchor, constant: 24),
            field.heightAnchor.constraint(equalToConstant: 38),
            line.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 20),
            line.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: failureBox.topAnchor, constant: -12),
            failureBox.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            failureBox.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            failureBox.bottomAnchor.constraint(equalTo: hint.topAnchor),
            failureLabel.widthAnchor.constraint(equalTo: failureBox.widthAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            hint.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            hint.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -16),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -12),
            settingsButton.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 28),
            settingsButton.heightAnchor.constraint(equalToConstant: 28),
            token.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            token.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            token.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
            argumentScroll.leadingAnchor.constraint(equalTo: token.trailingAnchor, constant: 12),
            argumentScroll.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            argumentScroll.topAnchor.constraint(equalTo: field.topAnchor),
            argumentScroll.heightAnchor.constraint(equalTo: field.heightAnchor),
            placeholder.leadingAnchor.constraint(equalTo: argumentScroll.leadingAnchor, constant: 10),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: argumentScroll.trailingAnchor, constant: -6),
            placeholder.centerYAnchor.constraint(equalTo: argumentScroll.centerYAnchor),
        ])
        failureHeight = failureBox.heightAnchor.constraint(equalToConstant: 0)
        failureHeight.isActive = true
        fieldLeading = field.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24)
        fieldLeading.isActive = true
        fieldLeadingAfterToken = field.leadingAnchor.constraint(equalTo: token.trailingAnchor, constant: 12)
    }

    @objc private func openSettingsFromLauncher() { onOpenSettings?() }

    func setEntries(_ entries: [LauncherEntry], refreshing: Bool = false) {
        index = SearchIndex(entries: entries)
        reloadResults()
        if results.isEmpty && refreshing && !pullRequestMode { emptyLabel.stringValue = "Discovering applications…" }
    }

    func renderPreview(to url: URL, argumentMode: Bool, emptyArgument: Bool = false, failure: Bool = false,
                       calculation: Bool = false) throws {
        field.stringValue = ""
        setEntries(ViewPreview.applications)
        if calculation {
            // Public fixtures only: a live result with remembered formulas below it.
            calculator = CalculatorState(history: [
                .init(expression: "24*3+10", result: "82", date: .distantPast),
                .init(expression: "24*60", result: "1440", date: .distantPast),
                .init(expression: "(5+5)*2", result: "20", date: .distantPast),
            ])
            field.stringValue = "24*3"
            reloadResults(preserveSelection: false)
            refreshHint()
        }
        if argumentMode {
            enterArgument(ViewPreview.command)
            if !emptyArgument {
                argumentInput.string = "release notes"
                placeholder.isHidden = true
            }
        }
        if failure {
            let id = beginScriptRun(ViewPreview.command)
            finishScriptRun(id, command: ViewPreview.command, argument: argumentInput.string,
                error: "Search Example: Exit code 1 — Unknown input prefix. Expected demo-*.\nCorrect the value and try again.")
        }
        guard let view = panel.contentView else { return }
        try ViewPreview.write(view, to: url)
    }

    func verifyScriptRunFeedback() throws {
        let command = ViewPreview.command
        let input = "  Unicode Привет 'quoted'\nsecond line  "
        var submissions: [String] = []
        onArgumentSubmit = { _, value in submissions.append(value) }
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw ConfigError.invalid(message) }
        }
        enterArgument(command)
        argumentInput.string = input
        let first = beginScriptRun(command)
        submitArgument()
        try check(submissions.isEmpty, "A running script was submitted twice.")
        finishScriptRun(first, command: command, argument: input, error: "Exit code 2 — Invalid input")
        try check(!failureBox.isHidden && !editInputButton.isHidden && argumentInput.isEditable
                  && argumentInput.string == input && failureLabel.stringValue.contains("Invalid input"),
                  "Failure did not preserve the input and display error/edit controls.")
        editInputButton.performClick(nil)
        try check(submissions.isEmpty && argumentInput.string == input, "Edit Input ran a script or changed its argument.")
        submitArgument()
        try check(submissions == [input], "Explicit retry did not submit the unchanged argument once.")
        let old = beginScriptRun(command)
        returnToSearch()
        finishScriptRun(old, command: command, argument: input, error: "Late failure")
        try check(argumentCommand == nil && field.isHidden == false && failureBox.isHidden && !panel.isVisible,
                  "A late failure reopened or overwrote a newer search.")
        enterArgument(command)
        let current = beginScriptRun(command)
        finishScriptRun(old, command: command, argument: input, error: "Stale failure")
        try check(activeRunID == current && failureBox.isHidden, "An older run replaced current feedback.")
        finishScriptRun(current, command: command, argument: input, error: nil)
        try check(activeRunID == nil && failureBox.isHidden && lastFailure == nil, "Success retained an error.")
        let noInput = beginScriptRun(command)
        finishScriptRun(noInput, command: command, argument: nil, error: "Missing executable")
        try check(!failureBox.isHidden && editInputButton.isHidden, "A command with no argument offered input editing.")
        dismiss(restoreFocus: false)
        finishScriptRun(noInput, command: command, argument: input, error: "Late result after hiding")
        try check(lastFailure == nil && failureBox.isHidden && activeRunID == nil && latestRunID == nil,
                  "Hiding retained an error/input or allowed a late result to restore it.")
    }

    /// Offscreen check that launches reorder the empty search by frequency, are
    /// reported for saving and still order it in a fresh controller after a restart.
    func verifyUsageOrder() throws {
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw ConfigError.invalid(message) }
        }
        let entries = ["Alpha", "Beta", "Gamma"].map {
            LauncherEntry(id: "app:\($0.lowercased())", name: $0, fileURL: URL(fileURLWithPath: "/fixture/\($0).app"))
        }
        var saved: [[String: UsageRecord]] = []
        usage = [:]
        onUsageChange = { saved.append($0) }
        setEntries(entries)
        show()
        try check(results.map(\.name) == ["Alpha", "Beta", "Gamma"], "Without history the empty search must be alphabetical.")
        dismiss(restoreFocus: false)
        recordUse("app:gamma")
        recordUse("app:gamma")
        recordUse("app:beta")
        try check(saved.count == 3 && saved.last?["app:gamma"]?.count == 2 && saved.last?["app:beta"]?.count == 1,
                  "Each launch must be reported for saving with its running count.")
        show()
        try check(results.map(\.name) == ["Gamma", "Beta", "Alpha"], "The empty search is not ordered by frequency.")
        dismiss(restoreFocus: false)

        let restarted = LauncherPanelController()
        restarted.usage = UsageStore.decode(UsageStore.encode(saved.last ?? [:]))
        restarted.setEntries(entries)
        restarted.show()
        try check(restarted.results.map(\.name) == ["Gamma", "Beta", "Alpha"], "Frequency order did not survive a restart.")
        restarted.dismiss(restoreFocus: false)
    }

    /// Offscreen check of the calculator rows, copy-on-Enter, history suggestions and
    /// the remembered draft, using a private pasteboard so the real clipboard is untouched.
    func verifyCalculator() throws {
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw ConfigError.invalid(message) }
        }
        func type(_ text: String) {
            field.stringValue = text
            controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        }
        let board = NSPasteboard(name: NSPasteboard.Name("com.uficast.verify-calculator"))
        pasteboard = board
        let generalChanges = NSPasteboard.general.changeCount
        calculator = CalculatorState(history: [
            .init(expression: "12*12", result: "144", date: Date(timeIntervalSince1970: 20)),
            .init(expression: "12 + 30", result: "42", date: Date(timeIntervalSince1970: 10)),
        ])
        var persisted: [CalculatorState] = []
        onCalculatorChange = { persisted.append($0) }
        setEntries([
            LauncherEntry(id: "app:notes", name: "Notes", fileURL: URL(fileURLWithPath: "/fixture/Notes.app")),
            LauncherEntry(id: "app:calculator", name: "Calculator", fileURL: URL(fileURLWithPath: "/fixture/Calculator.app")),
        ])
        show()
        try check(panel.isVisible, "The launcher did not become visible for the calculator check.")
        try check(field.stringValue.isEmpty, "A launcher without a draft must open empty.")

        type("12")
        try check(!results.contains { $0.kind == .calculator || $0.kind == .history }, "A bare number was treated as a calculation.")
        type("12+")
        try check(results.map(\.kind) == [.history] && results.first?.alias == "12 + 30",
                  "Typing a formula start did not suggest the matching history entry.")
        try check(hint.stringValue.contains("Copy"), "The hint does not say that Enter copies the result.")
        type("calc")
        try check(results.map(\.kind) == [.application, .history, .history] && results.first?.name == "Calculator"
                  && table.selectedRow == 0, "calc did not keep the Calculator app first with history below it.")
        try check(hint.stringValue.contains("Open"), "The hint should say Open while the application row is selected.")
        type("calc 12*12")
        try check(results.map(\.kind) == [.calculator] && results.first?.name == "144" && results.first?.alias == "12*12",
                  "A valid formula did not produce exactly one live result row.")
        try check(hint.stringValue.contains("Copy"), "The hint does not say that Enter copies the result.")

        type("calc")
        table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        _ = control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertTab(_:)))
        try check(field.stringValue == "12*12" && results.first?.kind == .calculator,
                  "Tab did not move a history expression into the search field.")

        type("12+")
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        activateSelected()
        try check(board.string(forType: .string) == "42", "Enter on a history row did not copy its result.")
        try check(calculator.history.first?.expression == "12 + 30" && calculator.draft == nil && field.stringValue.isEmpty
                  && !panel.isVisible, "Copying a history entry did not bump it, clear the field and close the launcher.")

        show()
        type("2+2*3")
        try check(results.first?.name == "8", "2+2*3 did not give 8.")
        activateSelected()
        try check(board.string(forType: .string) == "8", "Enter did not copy the live result.")
        try check(calculator.history.first == CalculatorState.Entry(expression: "2+2*3", result: "8",
                                                                     date: calculator.history[0].date)
                  && calculator.draft == nil && !panel.isVisible, "Enter did not record the calculation and close.")

        show()
        type("7*")
        dismiss(restoreFocus: false)
        try check(calculator.draft == "7*", "Closing with an unfinished formula did not remember it.")
        show()
        try check(field.stringValue == "7*" && field.currentEditor()?.selectedRange.length == 2,
                  "The unfinished formula was not restored and selected on reopen.")
        type("notes")
        dismiss(restoreFocus: false)
        try check(calculator.draft == nil, "An ordinary search was remembered as a draft.")
        show()
        try check(field.stringValue.isEmpty, "The launcher reopened with a stale search.")
        dismiss(restoreFocus: false)

        try check(persisted.last == calculator && persisted.count >= 4, "State changes were not reported for saving.")
        try check(NSPasteboard.general.changeCount == generalChanges, "The check touched the real clipboard.")
        board.releaseGlobally()
    }

    /// Offscreen check of pull-request mode with fake `org/repo` data. `openURL` is
    /// injected, so no browser opens, and `gh` and the clipboard are never touched.
    func verifyPullRequests() throws {
        func check(_ condition: Bool, _ label: String, _ message: String) throws {
            if !condition { throw ConfigError.invalid("\(label): \(message)") }
        }
        func type(_ text: String) {
            field.stringValue = text
            controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        }
        func press(_ selector: Selector) {
            _ = control(field, textView: NSTextView(), doCommandBy: selector)
        }
        func fixture(_ number: Int, _ title: String, _ repository: String, _ created: TimeInterval) -> PullRequest {
            PullRequest(number: number, title: title, url: URL(string: "https://github.com/\(repository)/pull/\(number)")!,
                        repository: repository, createdAt: Date(timeIntervalSince1970: created), isDraft: false)
        }
        let fixtures = [
            fixture(377, "Add billing export", "org/api", 100),
            fixture(412, "Fix flaky retry in upload", "org/api", 300),
            fixture(398, "Flaky cache test, quarantine", "org/web", 200),
        ]
        let loadingHint = "Loading pull requests…  ·  Esc Back"
        let loadedHint = "↑↓ Select  ·  ↩ Open  ·  Esc Back"
        var opened: [URL] = []
        var openSucceeds = true
        openURL = { opened.append($0); return openSucceeds }
        let generalChanges = NSPasteboard.general.changeCount
        usage = [:]
        calculator = CalculatorState()
        let allEntries = [LauncherEntry(id: "app:notes", name: "Notes", fileURL: URL(fileURLWithPath: "/fixture/Notes.app"))]
            + BuiltInCommand.entries
        setEntries(allEntries)
        show()
        try check(panel.isVisible, "enter/loading", "The launcher did not become visible.")

        type("gh")
        let first = enterPullRequests(cached: nil)
        try check(first != nil && pullRequestMode && token.title == "gh" && !token.isHidden && !field.isHidden
                  && field.stringValue.isEmpty && argumentScroll.isHidden && results.isEmpty && !emptyLabel.isHidden
                  && emptyLabel.stringValue == "Loading pull requests…" && hint.stringValue == loadingHint,
                  "enter/loading", "Entering without a cached list did not show the loading state.")
        try check(field.placeholderString == "Filter pull requests…", "enter/loading", "The filter placeholder is wrong.")
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened.isEmpty, "enter/loading", "Enter opened something while loading.")

        finishPullRequestLoad(first!, pullRequests: fixtures, error: nil)
        try check(results.map(\.alias) == ["org/api #412", "org/web #398", "org/api #377"] && table.selectedRow == 0
                  && results.allSatisfy { $0.kind == .pullRequest } && emptyLabel.isHidden && hint.stringValue == loadedHint,
                  "list", "The loaded list is not newest first with row 0 selected and the loaded hint.")

        type("flaky")
        try check(results.map(\.alias) == ["org/web #398", "org/api #412"] && table.selectedRow == 0,
                  "filter", "The filter did not narrow the rows, best match first, and select row 0.")
        type("адфлн")
        try check(results.map(\.alias) == ["org/web #398", "org/api #412"], "filter", "A Russian-layout query did not match.")
        type("   ")
        try check(results.count == 3 && table.selectedRow == 0, "filter", "A whitespace-only filter did not show all rows.")
        type("zzzz")
        try check(results.isEmpty && !emptyLabel.isHidden && emptyLabel.stringValue == "No matching pull requests"
                  && hint.stringValue == loadedHint, "no match", "No match did not show its empty text.")
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened.isEmpty, "no match", "Enter opened something with no rows.")

        press(#selector(NSResponder.cancelOperation(_:)))
        try check(!pullRequestMode && panel.isVisible && token.isHidden && field.stringValue == "gh"
                  && field.placeholderString == "Search applications and commands…" && hint.stringValue == Self.defaultHint,
                  "leave", "Escape did not return to search with the previous query.")
        try check(enterPullRequests(cached: fixtures) == nil && results.count == 3 && hint.stringValue == loadedHint,
                  "leave", "Entering with a cached list did not show it at once.")
        press(#selector(NSResponder.insertTab(_:)))
        try check(pullRequestMode && results.count == 3 && field.stringValue.isEmpty, "leave", "Tab changed pull-request mode.")
        press(#selector(NSResponder.deleteBackward(_:)))
        try check(!pullRequestMode && panel.isVisible && field.stringValue == "gh",
                  "leave", "Backspace in an empty filter did not return to search.")

        let empty = enterPullRequests(cached: nil)!
        finishPullRequestLoad(empty, pullRequests: [], error: nil)
        try check(results.isEmpty && !emptyLabel.isHidden && emptyLabel.stringValue == "You have no open pull requests."
                  && hint.stringValue == loadedHint, "empty", "An empty list did not show its text.")
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened.isEmpty, "empty", "Enter opened something in an empty list.")

        returnToSearch()
        let late = enterPullRequests(cached: nil)!
        dismiss(restoreFocus: false)
        let hiddenResults = results.map(\.id)
        finishPullRequestLoad(late, pullRequests: fixtures, error: nil)
        try check(!panel.isVisible && !pullRequestMode && results.map(\.id) == hiddenResults && token.isHidden
                  && failureBox.isHidden, "late result", "A result after hiding changed the view or reopened the panel.")
        show()
        type("gh")
        let old = enterPullRequests(cached: nil)!
        returnToSearch()
        let current = enterPullRequests(cached: nil)!
        finishPullRequestLoad(old, pullRequests: fixtures, error: nil)
        try check(results.isEmpty && emptyLabel.stringValue == "Loading pull requests…" && hint.stringValue == loadingHint,
                  "late result", "An older load replaced the current loading state.")
        finishPullRequestLoad(current, pullRequests: fixtures, error: nil)
        try check(results.count == 3, "late result", "The current load was not honoured.")
        finishPullRequestLoad(current, pullRequests: [], error: "Repeated")
        try check(results.count == 3 && failureBox.isHidden, "late result", "A finished load was applied twice.")

        returnToSearch()
        let failing = enterPullRequests(cached: nil)!
        finishPullRequestLoad(failing, pullRequests: nil, error: "Unexpected output from gh.")
        try check(!failureBox.isHidden && !failureLabel.isHidden && editInputButton.isHidden
                  && failureLabel.stringValue == "Unexpected output from gh." && failureHeight.constant == 56
                  && results.isEmpty && emptyLabel.isHidden && hint.stringValue == "Esc Back",
                  "failure", "A failed load did not use the failure area and the Esc Back hint.")
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened.isEmpty, "failure", "Enter opened something after a failure.")
        dismiss(restoreFocus: false)
        show()
        try check(failureBox.isHidden && !pullRequestMode && token.isHidden && field.stringValue.isEmpty
                  && hint.stringValue == Self.defaultHint, "stale error", "Reopening showed a stale error or mode.")

        dismiss(restoreFocus: false)
        try check(!panel.isVisible && enterPullRequests(cached: nil) == nil && !pullRequestMode && token.isHidden
                  && !field.isHidden && pullRequestLoadID == nil && field.placeholderString == "Search applications and commands…",
                  "hidden panel", "Entering on a hidden panel started the mode.")
        show()
        try check(!pullRequestMode && token.isHidden && !field.isHidden && hint.stringValue == Self.defaultHint,
                  "hidden panel", "Reopening showed a stale mode.")

        type("gh")
        let entered = enterPullRequests(cached: nil)
        let second = enterPullRequests(cached: nil)
        try check(entered != nil && second == nil && pullRequestMode && pullRequestLoadID == entered && field.stringValue.isEmpty,
                  "double entry", "A second entry changed the mode or its load.")
        press(#selector(NSResponder.cancelOperation(_:)))
        try check(!pullRequestMode && field.stringValue == "gh", "double entry", "Escape did not restore the previous query.")

        let refreshLoading = enterPullRequests(cached: nil)!
        setEntries(allEntries, refreshing: true)
        try check(emptyLabel.stringValue == "Loading pull requests…", "refresh text", "A refresh replaced the loading text.")
        finishPullRequestLoad(refreshLoading, pullRequests: [], error: nil)
        setEntries(allEntries, refreshing: true)
        try check(emptyLabel.stringValue == "You have no open pull requests.", "refresh text",
                  "A refresh replaced the no-pull-requests text.")
        returnToSearch()
        type("gh")
        enterPullRequests(cached: fixtures)
        type("zzzz")
        setEntries(allEntries, refreshing: true)
        try check(results.isEmpty && emptyLabel.stringValue == "No matching pull requests", "refresh text",
                  "A refresh replaced the no-match text.")
        returnToSearch()
        setEntries(allEntries)

        type("gh")
        enterPullRequests(cached: fixtures)
        openSucceeds = false
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened == [fixtures[1].url] && panel.isVisible && pullRequestMode
                  && hint.stringValue == "Could not open the pull request." && usage.isEmpty,
                  "open failed", "A failed open did not keep the panel open with its message.")

        opened = []
        openSucceeds = true
        press(#selector(NSResponder.moveDown(_:)))
        press(#selector(NSResponder.insertNewline(_:)))
        try check(opened == [fixtures[2].url] && !panel.isVisible && !pullRequestMode, "open",
                  "Enter did not open the selected row once and close the panel.")
        try check(usage["builtin:gh"]?.count == 1 && !usage.keys.contains { $0.hasPrefix("pr:") } && usage.count == 1,
                  "open", "Opening did not record exactly the command's own usage.")
        show()
        try check(field.stringValue.isEmpty && !pullRequestMode && token.isHidden && calculator.draft == nil
                  && results.contains { $0.id == "app:notes" }, "open", "Reopening did not give a normal empty search.")

        type("7*")
        enterPullRequests(cached: fixtures)
        type("flaky")
        dismiss(restoreFocus: false)
        try check(calculator.draft == "7*", "draft query", "Hiding from the mode did not keep the previous calculator draft.")
        show()
        try check(field.stringValue == "7*" && !pullRequestMode, "draft query", "The draft was not restored on reopen.")
        dismiss(restoreFocus: false)
        calculator = CalculatorState()

        // Row layout: a pull request row gives the title the full width, shows
        // `repository #number` as a subtitle below it and no kind label on the right.
        let longTitle = String(repeating: "A very long pull request title ", count: 6)
        let draft = PullRequest(number: 653, title: longTitle, url: URL(string: "https://github.com/org/core/pull/653")!,
                                repository: "org/core", createdAt: Date(timeIntervalSince1970: 1), isDraft: true)
        let rowWidth: CGFloat = 720, rowHeight: CGFloat = 56
        let pullRow = EntryRow(frame: NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight))
        pullRow.configure(.pullRequest(draft), icons: icons)
        pullRow.layoutSubtreeIfNeeded()
        let pr = pullRow.layoutSnapshot
        try check(pr.kindHidden, "row layout", "A pull request row still shows its kind on the right.")
        try check(pr.name.maxX >= rowWidth - 20, "row layout", "The title does not use the full row width (ends at \(pr.name.maxX)).")
        try check(abs(pr.subtitle.minX - pr.name.minX) <= 1, "row layout", "The subtitle does not start under the title.")
        try check(pr.subtitle.maxY <= pr.name.minY + 1, "row layout", "The subtitle is not below the title.")
        try check(pr.name.maxY <= rowHeight && pr.subtitle.minY >= 0, "row layout", "The two lines do not fit in the row.")
        let plainRow = EntryRow(frame: NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight))
        plainRow.configure(LauncherEntry(id: "app:notes", name: "Notes", fileURL: URL(fileURLWithPath: "/fixture/Notes.app"), alias: "nt"),
                           icons: icons)
        plainRow.layoutSubtreeIfNeeded()
        let plain = plainRow.layoutSnapshot
        try check(!plain.kindHidden && abs(plain.subtitle.midY - plain.name.midY) <= 2, "row layout",
                  "An ordinary row changed: its kind must stay on the right and its alias on the title's line.")

        try check(NSPasteboard.general.changeCount == generalChanges, "clipboard", "The check touched the real clipboard.")
    }

    /// Offscreen regression check: asynchronous icon completion must update the
    /// existing AppKit cell without replacing rows or changing scroll position.
    func verifyNativeIconRefresh() throws {
        let entries = Array(ApplicationCatalog.discover(roots: ApplicationCatalog.defaultRoots).entries.prefix(50))
        guard !entries.isEmpty else { throw ConfigError.invalid("Native icon fixture applications are unavailable.") }
        setEntries(entries)
        panel.contentView?.layoutSubtreeIfNeeded()
        let originals = try results.indices.map { row in
            guard let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) as? EntryRow else {
                throw ConfigError.invalid("Could not construct a native launcher cell.")
            }
            return cell
        }
        let origin = table.enclosingScrollView?.contentView.bounds.origin
        let rowRects = results.indices.map { table.rect(ofRow: $0) }
        let deadline = Date().addingTimeInterval(10)
        while originals.contains(where: { !$0.hasLoadedIcon }) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        let loaded = originals.filter(\.hasLoadedIcon).count
        guard loaded == originals.count,
              results.indices.allSatisfy({ table.rect(ofRow: $0) == rowRects[$0] }),
              table.enclosingScrollView?.contentView.bounds.origin == origin else {
            throw ConfigError.invalid("Native icon refresh: \(loaded)/\(originals.count) loaded, or row geometry/scroll position changed.")
        }
    }

    /// Counts one use of an application or script; the next opening is ordered by it.
    func recordUse(_ id: String) {
        usage[id, default: UsageRecord()].record()
    }

    private func reloadResults(preserveSelection: Bool = true) {
        let previousID = preserveSelection && results.indices.contains(table.selectedRow) ? results[table.selectedRow].id : nil
        if pullRequestMode {
            results = PullRequestFilter.apply(field.stringValue, to: pullRequests).map(LauncherEntry.pullRequest)
        } else {
            results = argumentCommand.map { [$0.entry] } ?? searchResults(for: field.stringValue)
        }
        table.reloadData()
        // A failed pull-request load shows its message in the failure area instead.
        emptyLabel.isHidden = !results.isEmpty || (pullRequestMode && !failureBox.isHidden)
        emptyLabel.stringValue = !pullRequestMode ? "No matching applications or commands"
            : pullRequestLoadID != nil ? "Loading pull requests…"
            : pullRequests.isEmpty ? "You have no open pull requests." : "No matching pull requests"
        if !results.isEmpty {
            let selection = previousID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0
            table.selectRowIndexes(IndexSet(integer: selection), byExtendingSelection: false)
        }
    }

    /// Application search, plus a live result and remembered calculations when the
    /// text looks like a formula or starts with `calc`. `calc` keeps the Calculator
    /// app first and lists history below it.
    private func searchResults(for text: String) -> [LauncherEntry] {
        guard let query = CalculatorQuery.parse(text) else { return index.search(text, usage: usage) }
        var live: [LauncherEntry] = []
        if let value = Calculator.evaluate(query.expression) {
            live = [.calculatorResult(expression: query.expression, result: Calculator.format(value))]
        }
        let applications = query.mode == .keyword ? index.search(text, usage: usage) : []
        return live + applications + calculator.suggestions(for: query.expression).map(LauncherEntry.calculatorHistory)
    }

    private func refreshHint() {
        guard argumentCommand == nil, !pullRequestMode, failureBox.isHidden else { return }
        let kind = results.indices.contains(table.selectedRow) ? results[table.selectedRow].kind : nil
        hint.stringValue = kind == .calculator || kind == .history ? Self.calculatorHint : Self.defaultHint
        hint.textColor = .secondaryLabelColor
    }

    func tableViewSelectionDidChange(_ notification: Notification) { refreshHint() }

    func controlTextDidChange(_ notification: Notification) {
        if pullRequestMode {
            // Filtering keeps the loading or failure state and its hint.
            reloadResults(preserveSelection: false)
            if pullRequestLoadID == nil, failureBox.isHidden { showPullRequestHint(Self.pullRequestHint) }
            return
        }
        activeRunID = nil
        hideFailure()
        hint.stringValue = Self.defaultHint
        hint.textColor = .secondaryLabelColor
        reloadResults(preserveSelection: false)
        refreshHint()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        let cell = EntryRow()
        cell.configure(item, icons: icons)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { RoundedResultRow() }

    @objc private func activateSelected() {
        if pullRequestMode { openSelectedPullRequest(); return }
        guard activeRunID == nil else { showInputError("This script is still running."); return }
        if argumentCommand != nil { submitArgument(); return }
        guard results.indices.contains(table.selectedRow) else { return }
        let entry = results[table.selectedRow]
        if entry.kind == .calculator || entry.kind == .history { copyCalculation(entry); return }
        onSelect?(entry)
    }

    /// Enter on a result copies it, remembers the calculation and returns focus
    /// to the previous app so the result can be pasted right away.
    private func copyCalculation(_ entry: LauncherEntry) {
        pasteboard.clearContents()
        guard pasteboard.setString(entry.name, forType: .string) else {
            showInputError("Could not copy the result.")
            return
        }
        calculator.record(expression: entry.alias ?? "", result: entry.name)
        field.stringValue = ""
        dismiss()
    }

    /// Opens the selected row in the browser. Only the command's own use is
    /// recorded; individual pull requests are never counted.
    private func openSelectedPullRequest() {
        guard pullRequestLoadID == nil, results.indices.contains(table.selectedRow) else { return }
        guard openURL(results[table.selectedRow].fileURL) else {
            showInputError("Could not open the pull request.")
            return
        }
        recordUse(BuiltInCommand.pullRequests.entry.id)
        dismiss(restoreFocus: false)
    }

    func toggle() {
        if panel.isVisible { dismiss() } else { show() }
    }

    func show() {
        guard !panel.isVisible else { return }
        NSApp.unhideWithoutActivation()
        beforeShow?()
        previousApplication = NSWorkspace.shared.frontmostApplication
        if let frame = Self.targetScreen(for: previousApplication)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                         y: frame.minY + frame.height * 0.65 - panel.frame.height / 2))
        }
        field.stringValue = calculator.draft ?? ""
        reloadResults(preserveSelection: false)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        // Selected, so typing a new search simply replaces the remembered formula.
        if calculator.draft != nil { field.selectText(nil) }
        startMonitors()
    }

    /// The display of the focused app's front window, else the one under the pointer.
    static func targetScreen(for application: NSRunningApplication?) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return NSScreen.main }
        let window = application.flatMap { frontWindowBounds(pid: $0.processIdentifier) }
            .map { DisplayPlacement.cocoaRect(fromQuartz: $0, primaryScreenHeight: primary.frame.height) }
        let index = DisplayPlacement.screenIndex(window: window, pointer: NSEvent.mouseLocation, screens: screens.map(\.frame))
        return index.map { screens[$0] } ?? NSScreen.main
    }

    /// Window owner, layer and bounds are readable without Screen Recording or
    /// Accessibility; titles and contents are neither requested nor used.
    private static func frontWindowBounds(pid: pid_t) -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        // The list is ordered front to back; skip menus, panels and tiny helper windows.
        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let dictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  bounds.width >= 80, bounds.height >= 80 else { continue }
            return bounds
        }
        return nil
    }

    func dismiss(restoreFocus: Bool = true) {
        let query = argumentCommand != nil || pullRequestMode ? previousQuery : field.stringValue
        clearArgument()
        guard panel.isVisible, !isDismissing else { return }
        // An unfinished formula survives hiding; every other input is dropped.
        calculator.draft = CalculatorQuery.isDraft(query) ? query.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        isDismissing = true
        defer { isDismissing = false }
        stopMonitors()
        panel.orderOut(nil)
        if restoreFocus, let previousApplication, !previousApplication.isTerminated,
           NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            previousApplication.activate()
        }
        previousApplication = nil
    }

    func focusSearch() {
        if !panel.isVisible { show() }
        if argumentCommand != nil { returnToSearch() }
        panel.makeFirstResponder(field)
        field.selectText(nil)
    }

    func windowDidResignKey(_ notification: Notification) { dismiss(restoreFocus: false) }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if pullRequestMode { returnToSearch() } else { dismiss() }
            return true
        }
        if pullRequestMode {
            if commandSelector == #selector(NSResponder.deleteBackward(_:)), field.stringValue.isEmpty {
                returnToSearch(); return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) { return true }
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            activateSelected()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            guard !results.isEmpty else { return true }
            let delta = commandSelector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = max(0, min(results.count - 1, table.selectedRow + delta))
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            guard results.indices.contains(table.selectedRow) else { return true }
            let entry = results[table.selectedRow]
            if entry.kind == .calculator || entry.kind == .history {
                // Edit the expression: put it in the field and recalculate.
                field.stringValue = entry.alias ?? ""
                controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
                if let editor = field.currentEditor() { editor.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0) }
            } else { onArgumentSelection?(entry) }
            return true
        }
        return false
    }

    func enterArgument(_ command: ScriptCommand) {
        activeRunID = nil
        argumentInput.isEditable = true
        hideFailure()
        previousQuery = field.stringValue
        argumentCommand = command
        token.title = command.alias ?? command.name
        placeholder.stringValue = command.argumentPlaceholder
        argumentInput.string = ""
        argumentInput.undoManager?.removeAllActions()
        argumentInput.setAccessibilityLabel("Argument for \(command.name): \(command.argumentPlaceholder)")
        field.isHidden = true
        token.isHidden = false
        argumentScroll.isHidden = false
        placeholder.isHidden = false
        hint.stringValue = "Paste one argument  ·  ↩ Run  ·  Esc Back"
        hint.textColor = .secondaryLabelColor
        reloadResults()
        panel.makeFirstResponder(argumentInput)
    }

    /// Enters pull-request mode. A cached list is shown at once and nil is returned;
    /// without one the loading state is shown and the id of the new load is returned.
    @discardableResult
    func enterPullRequests(cached: [PullRequest]?) -> UUID? {
        // Not on a hidden panel, and never twice: a second entry would overwrite previousQuery.
        guard panel.isVisible, !pullRequestMode else { return nil }
        activeRunID = nil
        hideFailure()
        previousQuery = field.stringValue
        pullRequestMode = true
        pullRequests = cached ?? []
        pullRequestLoadID = cached == nil ? UUID() : nil
        field.stringValue = ""
        field.placeholderString = "Filter pull requests…"
        field.setAccessibilityLabel("Filter pull requests")
        fieldLeading.isActive = false
        fieldLeadingAfterToken.isActive = true
        token.title = BuiltInCommand.pullRequests.rawValue
        token.isHidden = false
        reloadResults(preserveSelection: false)
        showPullRequestHint(pullRequestLoadID == nil ? Self.pullRequestHint : Self.pullRequestLoadingHint)
        panel.makeFirstResponder(field)
        return pullRequestLoadID
    }

    /// Applies a finished load. A result for an older load, or one that arrives after
    /// the owner left the mode or hid the launcher, never changes the view.
    func finishPullRequestLoad(_ id: UUID, pullRequests: [PullRequest]?, error: String?) {
        guard pullRequestMode, pullRequestLoadID == id else { return }
        pullRequestLoadID = nil
        self.pullRequests = error == nil ? pullRequests ?? [] : []
        if let error {
            failureLabel.stringValue = error
            failureLabel.toolTip = error
            failureLabel.isHidden = false
            editInputButton.isHidden = true
            failureBox.isHidden = false
            failureHeight.constant = 56
        }
        reloadResults(preserveSelection: false)
        showPullRequestHint(error == nil ? Self.pullRequestHint : "Esc Back")
    }

    private func showPullRequestHint(_ text: String) {
        hint.stringValue = text
        hint.textColor = .secondaryLabelColor
    }

    func showInputError(_ message: String) {
        hint.stringValue = message
        hint.textColor = .systemRed
    }

    func beginScriptRun(_ command: ScriptCommand) -> UUID {
        let id = UUID()
        activeRunID = id
        latestRunID = id
        lastFailure = nil
        hideFailure()
        argumentInput.isEditable = false
        hint.stringValue = "Running \(command.name)…  ·  Esc Back"
        hint.textColor = .secondaryLabelColor
        return id
    }

    func finishScriptRun(_ id: UUID, command: ScriptCommand, argument: String?, error: String?) {
        // A late result must never reopen or replace a newer search/input.
        guard activeRunID == id, latestRunID == id else { return }
        if let error { lastFailure = (command, argument, String(error.prefix(700))) }
        activeRunID = nil
        argumentInput.isEditable = true
        if let lastFailure, error != nil { displayFailure(lastFailure) }
        else {
            hideFailure()
            if panel.isVisible { dismiss(restoreFocus: false) }
        }
    }

    private func displayFailure(_ failure: (command: ScriptCommand, argument: String?, message: String)) {
        failureLabel.stringValue = failure.message
        failureLabel.toolTip = failure.message
        failureLabel.isHidden = false
        editInputButton.isHidden = failure.argument == nil
        failureBox.isHidden = false
        failureHeight.constant = failure.argument == nil ? 56 : 90
        hint.stringValue = failure.argument == nil ? "Choose a command  ·  Esc Close" : "Edit the argument, then ↩ Retry  ·  Esc Back"
        hint.textColor = .secondaryLabelColor
    }

    private func hideFailure() {
        failureLabel.isHidden = true
        editInputButton.isHidden = true
        failureBox.isHidden = true
        failureHeight.constant = 0
    }

    @objc private func editFailedInput() {
        guard let failure = lastFailure, let argument = failure.argument else { return }
        enterArgument(failure.command)
        argumentInput.string = argument
        placeholder.isHidden = !argument.isEmpty
        displayFailure(failure)
        panel.makeFirstResponder(argumentInput)
        argumentInput.setSelectedRange(NSRange(location: 0, length: argument.utf16.count))
    }

    @objc private func returnToSearch() {
        clearArgument()
        field.stringValue = previousQuery
        reloadResults()
        panel.makeFirstResponder(field)
        if let editor = field.currentEditor() { editor.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0) }
    }

    private func clearArgument() {
        activeRunID = nil
        latestRunID = nil
        lastFailure = nil
        argumentInput.isEditable = true
        hideFailure()
        argumentCommand = nil
        argumentInput.string = ""
        argumentInput.undoManager?.removeAllActions()
        pullRequestMode = false
        pullRequests = []
        pullRequestLoadID = nil
        field.placeholderString = "Search applications and commands…"
        field.setAccessibilityLabel("Search applications and commands")
        fieldLeadingAfterToken.isActive = false
        fieldLeading.isActive = true
        field.isHidden = false
        token.isHidden = true
        argumentScroll.isHidden = true
        placeholder.isHidden = true
        hint.stringValue = Self.defaultHint
        hint.textColor = .secondaryLabelColor
    }

    private func submitArgument() {
        guard activeRunID == nil else { showInputError("This script is still running."); return }
        guard let command = argumentCommand else { return }
        let value = argumentInput.string
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showInputError("Enter an argument before running."); return
        }
        guard !value.contains("\0") else { showInputError("The argument contains a null character."); return }
        onArgumentSubmit?(command.id, value)
    }

    func textDidChange(_ notification: Notification) { placeholder.isHidden = !argumentInput.string.isEmpty }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            returnToSearch(); return true
        }
        if commandSelector == #selector(NSResponder.deleteBackward(_:)), textView.string.isEmpty {
            returnToSearch(); return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { submitArgument(); return true }
        if commandSelector == #selector(NSResponder.insertTab(_:)) { return true }
        return false
    }

    private func startMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.window !== self.panel { self.dismiss(restoreFocus: false) }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss(restoreFocus: false) }
        }
    }

    private func stopMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }
}

private final class ClickThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}


@MainActor
private final class RoundedResultRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 12, yRadius: 12).fill()
    }
}

@MainActor
private final class EntryRow: NSTableCellView {
    private let icon = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let alias = NSTextField(labelWithString: "")
    private let kind = NSTextField(labelWithString: "")
    private var representedURL: URL?
    private var inlineConstraints: [NSLayoutConstraint] = []
    private var subtitleConstraints: [NSLayoutConstraint] = []
    private var usesSubtitleLayout = false
    var hasLoadedIcon: Bool {
        icon.image?.representations.contains { $0 is NSBitmapImageRep && $0.pixelsWide == 64 && $0.pixelsHigh == 64 } ?? false
    }
    /// Label frames after layout, for the native layout checks.
    var layoutSnapshot: (name: NSRect, subtitle: NSRect, kindHidden: Bool) {
        (name.frame, alias.frame, kind.isHidden)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        name.font = .systemFont(ofSize: 18, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        alias.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        alias.textColor = .secondaryLabelColor
        kind.font = .systemFont(ofSize: 14)
        kind.textColor = .secondaryLabelColor
        for view in [icon, name, alias, kind] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30), icon.heightAnchor.constraint(equalToConstant: 30),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            kind.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            kind.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        // Ordinary rows: title, alias on the same line, kind on the right.
        inlineConstraints = [
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            alias.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 12),
            alias.centerYAnchor.constraint(equalTo: centerYAnchor),
            alias.trailingAnchor.constraint(lessThanOrEqualTo: kind.leadingAnchor, constant: -16),
        ]
        // Pull request rows: the title over the full width, the subtitle below it.
        subtitleConstraints = [
            name.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 3),
            name.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            alias.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            alias.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 1),
            alias.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
        ]
        NSLayoutConstraint.activate(inlineConstraints)
    }

    private func showSubtitle(_ shows: Bool) {
        guard shows != usesSubtitleLayout else { return }
        usesSubtitleLayout = shows
        NSLayoutConstraint.deactivate(shows ? inlineConstraints : subtitleConstraints)
        NSLayoutConstraint.activate(shows ? subtitleConstraints : inlineConstraints)
        alias.font = .monospacedSystemFont(ofSize: shows ? 12 : 13, weight: .regular)
        kind.isHidden = shows
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ entry: LauncherEntry, icons: IconStore) {
        representedURL = entry.fileURL
        if let command = BuiltInCommand(entryID: entry.id), entry.kind == .builtIn {
            icon.image = NSImage(systemSymbolName: command.symbolName, accessibilityDescription: nil)
        } else if entry.kind == .pullRequest {
            icon.image = NSImage(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: nil)
        } else if entry.kind == .calculator || entry.kind == .history {
            icon.image = NSImage(systemSymbolName: entry.kind == .calculator ? "equal.circle.fill" : "clock.arrow.circlepath",
                                 accessibilityDescription: nil)
        } else {
            icon.image = icons.icon(for: entry.fileURL) { [weak self] image in
                guard let self, self.representedURL == entry.fileURL else { return }
                self.icon.image = image ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            }
        }
        let isCalculation = entry.kind == .calculator || entry.kind == .history
        showSubtitle(entry.kind == .pullRequest)
        name.stringValue = isCalculation ? "= \(entry.name)" : entry.name
        alias.stringValue = entry.alias ?? ""
        kind.stringValue = entry.kind.title
        // The kind is hidden on pull request rows but still read by VoiceOver.
        setAccessibilityLabel(isCalculation ? "\(entry.alias ?? "") equals \(entry.name), \(kind.stringValue)"
                              : entry.kind == .pullRequest ? "\(entry.name), \(entry.alias ?? ""), \(kind.stringValue)"
                              : "\(entry.name), \(kind.stringValue)")
    }
}

/// A subtle field surface resolved in the current appearance, without the
/// opaque control/clip-view background that clashes with the popover material.
private final class ArgumentScrollView: NSScrollView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.07).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        super.draw(dirtyRect)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
