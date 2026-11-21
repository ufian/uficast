# Implementation plan

Implement stages in order. A stage is a reviewable unit and may span more than one session; do not force unfinished work into a single token budget. Every stage ends with working-tree review, appropriate validation, a progress update, and a commit. Record a checkpoint if interrupted midway.

## Stage 0 — Plan and durable context

**Deliverable:** requirements, architectural decisions, this plan, and a next-session handoff committed to Git.

**Complete when:** the owner's decisions and defaults are distinguishable; the next implementation action is explicit. No app implementation or system settings changes are part of this stage.

## Stage 1 — Buildable app and global-trigger spike

**Purpose:** prove the highest-risk platform behavior before building the full launcher.

Tasks:

- Create SwiftPM targets, minimal test setup, Info.plist, ignored build directories, and a reproducible `.app` packaging script.
- Add a menu bar entry with Open, Settings placeholder, Quit, and visible hotkey-registration status.
- Show a minimal input-capable NSPanel from the menu; include a real Edit menu.
- Implement ordinary Cmd+Space with Carbon RegisterEventHotKey, exclusive-conflict reporting and pressed/released repeat debouncing. No Accessibility or Input Monitoring requests or keyboard event taps.
- Verify no privacy grant is needed for launcher registration and establish local signing/install behavior on macOS 26. Do not change existing shortcut assignments automatically.

Validation:

- Build/package with Command Line Tools and launch the bundle, not only the SwiftPM executable.
- Owner-assisted check: Cmd+Space opens/closes once per press using either Command key, with no Accessibility/Input Monitoring. The owner must release conflicting Spotlight/Raycast bindings; check extra modifiers and repeats.
- No leaked Space/repeat or stuck modifier when Command is released before Space. Repeat after sleep/wake and shortcut retry.
- The panel accepts Cmd+V and returns focus after Escape. Check normal and full-screen apps and two displays when available.

**Exit gate:** a recorded Carbon implementation for ordinary Cmd+Space without Accessibility. Verify Spotlight coexistence with the conflicting system binding released by the owner; never silently reassign system settings. Unavailable manual checks must be recorded as pending before proceeding past this gate.

Suggested commit: `feat: scaffold native app and global-shortcut launcher trigger`.

## Stage 2 — Application catalog and fast search

Tasks:

- Add stable app/script item models and initial search engine.
- Discover configured application roots without listing nested helpers; deduplicate by identity and handle missing/moved apps.
- Render icon/name/type rows, selection, empty state, keyboard navigation, Enter launch/activate, outside-click dismissal, and screen placement.
- Implement deterministic exact/prefix/substring/fuzzy ranking with reserved top priority for exact aliases.
- Refresh the catalog asynchronously and load icons without blocking query changes.

Validation:

- Unit tests for rank tiers, fuzzy ordering, case normalization, exact-alias precedence, and stable tie-breaking.
- Launch a real app and activate an already running app. Check new/removed apps and manual Refresh.
- Measure warm search over a fixture catalog of 2,000 items; initial target p95 below 30 ms. Warm panel-show target below 100 ms on the development Mac. Record measured conditions; targets are not achieved until measured.

**Complete when:** it is a usable app launcher even before script support; discovery never blocks typing.

Suggested commit: `feat: add application discovery and ranked launcher search`.

## Stage 3 — Settings, persistence, and aliases

Tasks:

- Implement versioned ConfigStore with validation, atomic save, last-known-good backup, and recovery messages.
- Build General and Commands settings matching the reference structure: search, All/Apps/Scripts filters, table, Alias and Enabled editing, and add control.
- Persist app overrides separately from discovery; implement unique aliases across enabled entries and exact-alias selection.
- Add custom application roots and application paths, plus manual catalog Refresh.
- Support basic export/import with validation and explicit handling of machine-specific script/app paths; do not assume portability of absolute paths.

Validation:

- Round-trip configuration and restart the packaged app with aliases/enabled state intact.
- Test conflicting aliases, disabled records, missing app paths, corrupt JSON, and unsupported future schema without data loss.
- Compare light/dark Settings and launcher visually against the described screenshot hierarchy. Check tab order and standard editing shortcuts.

**Complete when:** the owner can configure and launch an application alias entirely through the UI.

Suggested commit: `feat: add raycast-inspired settings and persistent aliases`.

## Stage 4 — Local script runner

Tasks:

- Add script CRUD and editor fields: executable/interpreter, argument requirement/placeholder, result mode, timeout, working directory, environment.
- Implement shell, osascript, and executable/script invocation with exact argv and no input interpolation.
- Add asynchronous, bounded stdout/stderr handling, timeout/cancellation, duplicate-run protection, and useful error status.
- Add a bounded recent-run status view and generic example scripts, including an AppleScript using `on run argv` and a public fixture URL generator.
- Document PATH behavior and test Automation consent from the built bundle when an AppleScript controls another app.

Validation:

- Integration fixtures assert one unchanged argument containing spaces, quotes, Unicode, shell metacharacters, and newlines; verify the input has no shell side effects.
- Cover success, no argument, missing file/interpreter, permission denied, nonzero exit, excessive simultaneous stdout/stderr, and timeout with a spawned child.
- Verify no UI freeze while a script is running and no automatic opening of stdout in discard mode.

**Complete when:** script commands work through the runner and editor, with explicit result contracts ready for argument-mode integration.

Suggested commit: `feat: add configurable local script execution`.

## Stage 5 — Inline argument workflow and browser result

Tasks:

- Implement the explicit search/argument state transition and pinned command token/field layout.
- Support `k` → Tab → Cmd+V → Enter, Enter-to-enter-argument-mode, and Escape/empty-Backspace return behavior.
- Pass exactly one field value; validate required content without altering the submitted text.
- Add openURL result validation and NSWorkspace opening on successful exit only.
- Preserve useful error discoverability without stealing focus from the browser or reopening the panel.

Validation:

- Full packaged-app workflow using a generic Kibana-style command: alias `k`, placeholder `log_stream`, encoded test argument, default browser open.
- Confirm Cmd+V, select/copy/cut/undo, Unicode input, newlines, whitespace validation, and reopening the launcher.
- Test malformed URL, multiple URLs/lines, unsupported scheme, empty output, nonzero exit, timeout, and single-open behavior.
- Migrate the owner's real Kibana script only when its source is available; generic success does not prove that private script works.

**Complete when:** the central interaction from the first screenshot works end to end.

Suggested commit: `feat: add inline script arguments and URL results`.

## Stage 6 — Caps Lock remapping and login lifecycle

Tasks:

- Add a hidutil mapping adapter with read/merge/write behavior and an ownership/recovery record.
- Implement explicit enable/disable of Caps Lock → F19, preserving unrelated mappings and handling pre-existing identical/conflicting mappings.
- Reconcile owned mappings on startup and wake/device reconnect; handle normal quit and crash recovery without a separate daemon.
- Add Settings status, conflict explanations, and instructions for assigning F19 to the macOS input-source switching shortcut.
- Add optional start-at-login through SMAppService and report actual authorization status.

Validation:

- Test merge/restore/ownership logic with fixtures; test failures without mutating the real machine.
- During an explicit owner-approved setup/test, verify Caps Lock emits F19 and the configured system action switches the existing two layouts; compare perceived delay with the previous configuration.
- Test preservation of another mapping, external Caps Lock changes, enabling an already externally managed F19 mapping, restart, sleep/wake, keyboard reconnect, normal quit, and recovery after simulated crash.
- Validate actual relogin behavior with start-at-login enabled; report manual checks still pending.

**Complete when:** the owner has a working system shortcut and mapping lifecycle is understood and documented. A mapping-only test does not prove improved layout-switching latency.

Suggested commit: `feat: add caps-lock remapping and launch-at-login`.

## Stage 6b — Built-in Keep Awake (owner addition)

Use a native IOPM PreventUserIdleDisplaySleep assertion owned by this app. The owner clarified that caffeine must also keep the screen on, superseding the initial system-only default. Provide a menu toggle, 30-minute / one-hour / indefinite sessions, visible state and General settings controls. Original default-off-on-every-launch behavior is superseded by Stage 6k; first installation still starts off; release on stop, expiry and normal quit. macOS releases a process-owned assertion on exit. Idle display and system sleep are prevented; explicit Sleep and lid behavior remain governed by macOS. No Accessibility, Input Monitoring or caffeinate subprocess.

Validate acquire/renew/stop ownership, expiry and backend failures using a fake backend without changing actual power assertions. Real idle-sleep acceptance remains a manual check initiated by the owner.

Suggested commit: `feat: add built-in keep-awake sessions`.

## Stage 6c — Owner additions: app shortcuts, launch lifecycle and icons

- Show the launcher on first/open/reopen; add a Settings gear button.
- Enforce one normal app process per user with a process-held lock and reveal notification.
- Double-click an app Hotkey cell to record inline; Escape cancels with the previous value intact. Verify capture, clear and registration restoration on focus/window/cell lifecycle changes.
- Persist and record per-app global shortcuts without Accessibility; validate duplicates/reserved chords and implement native activate/hide/launch behavior.
- Show real icons in both lists, with bounded background loading and direct existing-cell updates to avoid reload jitter.
- Put the startup checkbox at the top of General.
- Diagnose conflicting system Caps Lock modifier profiles and reapply owned mappings when keyboard services appear.

Validate lock exclusivity/release, configuration compatibility, hotkey conflicts and keyboard-profile detection with fixtures. Check native icon completion using --verify-native-icons. Record startup, Settings navigation and visual observations separately from remaining physical hotkey, reconnect and login checks.

## Stage 6d — Wrong-layout search (owner addition)

Expand search queries using standard U.S./Russian physical-key mappings in both directions. Preserve exact-alias priority, favor literal matches within each rank tier, and deduplicate results. Apply to launcher and Commands search only; arguments remain unchanged. Validate both directions, mixed input, alias precedence and ё/й mapping, plus the existing 2,000-app performance target.

## Stage 6e — Inline app hotkeys and removal (owner addition)

Double-click an application's Hotkey cell to record inline. Escape cancels without a save; retain the prior assigned/unassigned value. Single clicks select, valid chords save, and Delete or the adjacent × explicitly removes an assignment. Restore Uficast registrations on focus/window/cell lifecycle changes. Check with native fixture responder events and a real Settings double-click/Escape pass, without saving a test assignment to personal config.

## Stage 6f — Built-in caffeine commands (owner addition)

Add caffeine / decaffeine entries and cafe / decafe abbreviations to launcher search. Show a cup while active and zzz in decaf mode, including startup and the decaffeine result icon. Use the existing native power service for indefinite enable and disable; do not spawn scripts. Cover exact/short/fuzzy/wrong-layout searches and user-alias precedence. Keep real power acceptance separate from fixture tests.

## Stage 6g — Script-folder UX (owner addition)

Connect a folder from Commands, reference its direct script files, and infer interpreter/title/one text argument from known suffixes, shebang and Raycast comment headers. Keep existing per-command customizations, deduplicate by canonical file path, preserve unavailable roots, and disconnect without deleting source files. Add explicit Refresh Scripts and startup refresh. Test discovery without execution, legacy configuration, removed/unavailable folders, unsupported metadata and manual duplicates. Verify the actual add-folder workflow without running private scripts; screenshots must retain only public fixtures.

## Stage 6h — Inline aliases (owner addition)

Edit aliases in the table/inspector by double-click; Enter commits, Escape cancels and × removes. Validate before closing so duplicate/invalid drafts remain editable. Check app/script edits, exact save counts and lifecycle cancellation with native fixture field-editor events. Replace the old inspector Apply flow.

## Stage 6i — Argument appearance and script errors (owner addition)

Remove the opaque white input surface, align placeholder/text insets and inspect empty/filled light/dark previews. Keep the launcher open during execution, close on success, and show a bounded failure footer with Edit Input. Preserve the exact argument, retry only on Enter, prefer stderr with stdout fallback, and reject stale completion updates after dismissal/navigation. Test native presentation plus real generic subprocess failures; do not run private scripts for verification.

## Stage 6j — Window keyboard conventions (owner addition)

Esc closes Settings after cancelling inline edits first. Keep sheet cancellation intact. Add Cmd+P as the owner's additional Settings shortcut and retain standard Cmd+,. Supply relevant native menu commands for close, find, hide, minimize, quit and text editing; local recording must take precedence. Research primary Apple references and verify routing with native fixtures and deliberate desktop actions.

## Stage 6k — Remembered caffeine and transient errors (owner additions)

Persist local caffeine/decaf mode and optional expiry. Restore indefinite or remaining timed sessions, not expired ones; snapshot before releasing on quit and suppress initial/cleanup observer writes. Test with fake assertions and Codable fixtures, without changing actual power state merely to test. Clear launcher errors/input on every hide and reject late results before they can be remembered or shown on reopen.

## Stage 6l — Day-O menu-bar calendar (owner addition)

Developed on the separately requested codex/day0-calendar-experiment branch after the adjacent chat completed; the owner authorized integration into main on November 18, 2026. Make the clock Uficast's single status button; preserve Keep Awake through its menu. Use the standard compact AppKit NSDatePicker found in Day-O, with month browsing/Today and reset on opening. Add General format/Show Icon preferences with backward-compatible persistence. Keep diagnostics out of the root menu so it stays narrow. Verify horizontal centering inside an actual open NSMenu, including when command rows widen it. Keep a zzz/cup state indicator to the left of the calendar within the single button. Anchor seconds to system boundaries and resynchronize after wake/time changes.

Validate legacy config/defaults/round trip/format limits, native light/dark previews, native menu-tracking tick phases, release build and signature. Record actual menu navigation and side-by-side timing separately; never claim unperformed physical checks. Integration is approved; remaining manual checks still require observed evidence.

## Stage 6m — Launcher shortcut, focus display and clock contrast (owner additions)

Make the launcher shortcut configurable in General with Cmd+Space as the default, absent-field compatibility and conflict checks against app hotkeys in both directions. Probe a new combination before saving it. Open the launcher on the display of the focused app's front window, falling back to the pointer. As an owner-chosen experiment, draw the clock text and icons as one explicit-contrast image so it may stay readable on an inactive display. Design: `docs/superpowers/specs/2026-11-19-launcher-hotkey-display-clock-design.md`.

Validate with core tests (legacy decode, round trip, validation, conflicts, display geometry), native recorder/clock checks, light/dark previews and a release build. Physical shortcut delivery and two-display placement require the owner's observation. The owner confirmed inactive-display clock readability on November 19, 2026.

## Stage 6n — AI text rewrite and translation (owner addition)

Rewrite into correct, simple English and translate EN↔RU through an owner-editable CLI command (default `claude -p` with Haiku 5.5), from the clipboard or macOS Services, showing the result first and keeping inline formatting. Design: `docs/superpowers/specs/2026-11-19-ai-text-rewrite-translate-design.md`; task plan: `docs/superpowers/plans/2026-11-19-ai-text-rewrite-translate.md`. Validate with core tests (stdin worker, runner, prompt, markers, configuration), `--verify-ai-text` and a release build; real Services replacement, formatting in Mail/Notes and a Codex command need the owner's observation.

## Stage 6o — Calculator (owner addition)

Evaluate formulas typed in the launcher, copy the result on Enter, remember calculations and offer them as suggestions below the results, and restore an unfinished formula when the launcher reopens. See REQUIREMENTS "Calculator" and ARCHITECTURE "Calculator (Stage 6o)". Validate with core tests (evaluator, formatting, query detection, history, draft, codable state), `--verify-calculator` on a private pasteboard, light/dark previews and a release build. Physical typing, paste into another app and relaunch persistence need the owner's observation.

## Stage 6p — Persistent frequency ordering (owner addition)

Remember launch counts across restarts so the empty search and equal matches stay ordered by frequency. See REQUIREMENTS "Frequency ordering" and ARCHITECTURE "usage.v1". Validate with core tests (record, codable round trip, restart ordering, recency tie-break, corrupt/negative data, entry limit, no paths), `--verify-usage-order` and a release build. Real relaunch ordering needs the owner's observation.

## Stage 6q — Shortcuts instead of Services (owner addition)

Remove the macOS Services entry point (nested event loop, replace mode, `NSServices`) and add the `uficast://rewrite|translate?text=…` link and Settings buttons for a Shortcuts-based entry. The first try (a generated `.shortcut` file) was rejected by Shortcuts as unsigned, so the buttons now open an empty shortcut, copy a script and show the steps. Validate with core tests (link parsing; the script run in zsh against `AITextURL`), `--verify-ai-text` (link flows, refused links, clipboard formatting) and a release build. Building the shortcut, selection input and its keyboard shortcut need the owner's observation.

## Stage 6r — Compact settings (owner addition)

Rearrange Settings → General into two columns of cards with one-row settings, ⓘ popovers for long explanations, a slim top bar and a footer with Recent Runs, so it fits the window without scrolling. Keep every control's behavior. Validate with light/dark offscreen previews (including a very small window), the existing native checks that host the Settings view, core tests and a release build. The owner's hands-on look is required.

## Stage 7 — Daily-use verification and source-build handoff

Tasks:

- Run a focused end-to-end pass across app launch, aliases, argument scripts, browser results, focus, remapping, and login lifecycle.
- Polish reference fidelity, spacing, icons, keyboard focus, light/dark appearance, and empty/error states based on actual screenshots.
- Verify all required permissions and rebuilding/installing behavior. Document known limitations, including Secure Input or privacy regrant if observed.
- Finish README with build/install/run instructions, configuration locations and backup, script examples, F19 setup/reversal, and troubleshooting.
- Record actual performance numbers and outstanding manual/platform limitations. Make sure private URLs/config and build output are ignored.

Validation:

- Build a release `.app` from a fresh source directory/check-out using only documented steps and available Command Line Tools.
- Run the targeted test suite and the end-to-end acceptance list in REQUIREMENTS; repeat checks only when subsequent changes justify it.
- Owner daily-use trial for opening apps and the real `k` workflow when its script is provided.

**Complete when:** all confirmed v1 requirements have evidence, remaining limitations are explicit, and another personal Mac can build from source using the README. Do not claim tests on another Mac or a reboot happened unless they did.

Suggested commit: `docs: finalize build guide and v1 validation` (include polish changes in a separate commit if substantial).

## Session boundary protocol

1. Read PROGRESS and inspect `git status`; preserve unrelated work.
2. Work on the next unfinished stage, respecting its dependencies and exit gate.
3. Run meaningful checks appropriate to changed behavior. Pure documentation edits need link/content/diff review, not application tests.
4. Update PROGRESS with stage state, implemented paths, commands and results, pending manual checks, blockers, and the next concrete action.
5. Record changed decisions in ARCHITECTURE/REQUIREMENTS and adjust later tasks if needed.
6. Review the diff and commit relevant files. A commit checkpoint is not evidence a stage passed validation.

Resume prompt for future sessions:

> Read AGENTS.md and docs/plan/PROGRESS.md, then continue the next unfinished stage of docs/plan/IMPLEMENTATION_PLAN.md. Follow the agreed requirements and architecture, update the handoff with actual verification results, and commit the completed increment.
