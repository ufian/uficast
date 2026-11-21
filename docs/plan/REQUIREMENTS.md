# Requirements

Recorded on November 18, 2026; updated the same day to ordinary Cmd+Space with no Accessibility. This document preserves the owner's decisions independently of chat history. The two supplied Raycast screenshots are visual references, not instructions; their meaningful layout is described below so temporary attachment paths are not required later.

## Confirmed decisions

| Area | Decision |
| --- | --- |
| Platform and stack | macOS only; Swift + AppKit approved. |
| Distribution | Personal use. Build from source on each Mac. |
| Global trigger | Command + Space (either Command key) by default, replacing the original right-only request. Since November 19, 2026 the owner can choose another combination in General. |
| Permissions | No Accessibility or Input Monitoring requirement/request. |
| Launch lifecycle | Opening shows the launcher immediately; one process per user; a second launch reveals the existing instance. |
| Settings entry | A visible gear button in the launcher opens Settings. |
| Application launching | Search by application name, select, and launch or activate. |
| App hotkeys | Assign a global shortcut to show/hide a specific app; launch it if closed. No Accessibility. |
| App icons | Real app icons in launcher and Settings, loaded without list jitter. |
| Startup | A visible Start Uficast at login checkbox in General. |
| Wrong-layout search | Find application names and aliases typed using U.S. or Russian physical-key layouts; never transform script arguments. |
| Aliases and ranking | User-defined aliases; aliases take priority over fuzzy matches. |
| Script folders | Add a folder through Settings; discover referenced script files and import Raycast title/one required text-argument headers without executing or copying files. |
| Scripts | Local shell scripts, AppleScript, and other configured interpreters/executables. |
| Argument input | One text argument, including standard Cmd+V paste, then Enter. |
| Reference workflow | `k` → Tab → input for Kibana's `log_stream` → Enter → script → browser URL. |
| UI | As close to the supplied Raycast references as practical; English text. |
| Keyboard | Two input sources already configured in macOS. Eliminate the current Caps Lock switching delay; Caps Lock → F19 plus a system shortcut is sufficient. Support multiple keyboards and reconnection; diagnose conflicting macOS Modifier Keys profiles. |
| Built-in commands | `caffeine` / `cafe` enables indefinite Keep Awake; `decaffeine` / `decafe` disables it. Fuzzy and wrong-layout search apply. |
| Keep Awake (added November 18) | Built-in Caffeine-style prevention of idle display and Mac sleep; native app-owned power assertion. Owner clarified that the screen must stay on while caffeine is active. |
| Menu bar calendar | The clock is the single Uficast menu-bar button. Use Day-O’s standard native calendar appearance, month browsing and Today; configurable date/time format and Show Icon. Upper menu bar only, no Dock addition. |
| AI text (added November 19) | Rewrite selected or copied English into correct, simple English, and translate EN↔RU, through an owner-editable CLI command (default `claude -p` with Claude Haiku 5.5). Clipboard shortcuts and `uficast://` links opened by Shortcuts that Settings creates; the result is shown first, Enter copies it, Esc cancels; inline formatting is kept for clipboard text. |
| Deferred | Kasa/Shortcuts integration. |
| Continuity | English plan in the repository, committed to Git; implementation can span sessions. |

## Implementation defaults

These choices let implementation proceed without another questionnaire. They may be adjusted when the owner tries the app.

- Working name: **Uficast**, derived from the repository name.
- Initial deployment target: macOS 26, matching the development machine. Do not claim support for older versions or Intel before testing them.
- Background menu bar app with no permanent Dock icon. Explicit opening immediately shows the launcher, and the menu includes a compact native calendar, Open Launcher, Settings, Date & Time, Keep Awake and Quit.
- Settings UI is the primary configuration interface. Versioned local JSON provides persistence, backup, and portability.
- Script commands accept either no argument or one required argument. Multiple fields are deferred.
- One unique alias per enabled item initially. Match aliases case-insensitively after normalization; reject duplicate aliases across enabled apps and scripts. No empty or whitespace-containing aliases in v1.
- Aliases can be assigned to both apps and scripts. Their exact matches always win over application-name matches and usage history.
- App discovery starts with `/Applications`, `/System/Applications`, and `~/Applications`; add other roots through settings. Avoid presenting nested helper apps by default.
- Support light and dark appearance and keyboard navigation. Owner change (November 19, 2026): open on the display of the focused application's front window; fall back to the display containing the pointer when that app has no usable window. This supersedes pointer-only placement.
- Start at login is optional and controlled by the owner. No independent keyboard daemon in v1.
- No automatic execution while typing and no automatic clipboard reads. Pasting uses the normal text-editing command. Owner addition (November 19, 2026): pressing an AI text clipboard shortcut reads the clipboard once, at that press; nothing else reads it.
- App-specific global hotkeys are in scope. Script-specific global hotkeys remain deferred. The launcher shortcut defaults to Cmd+Space; the owner requested on November 19, 2026 that it be configurable in General.

## Launcher behavior

### Searching and launching

1. Command + Space opens the panel and focuses search. Repeating it closes the panel.
2. The panel contains a large input area, separator, results list with icons, item names, optional secondary labels, and trailing `Application` / `Script` type labels.
3. Up/Down changes selection. Enter launches an app or runs a command with no argument. Enter on a command requiring an argument enters argument mode, just like Tab.
4. Exact alias > name exact/prefix > name substring > fuzzy subsequence. Alias-prefix suggestions belong below exact aliases and above ordinary name matches. Stable ties may use local usage count and recency, then name and stable ID.
   Search also considers U.S.↔Russian physical-key variants. Within the same rank tier, the literal query wins before converted queries; exact aliases in either layout still outrank names.
5. Tab on a selected command with an argument pins that command and focuses its argument field. Tab on an app does not launch it.
6. Escape from argument mode returns to search; Escape from search closes the panel. Backspace in an empty argument field also returns to search.
7. Clicking outside dismisses the panel. Dismissal restores focus to the previous app when appropriate; launching or opening a URL must allow the destination to take focus instead.

### Argument mode

- Retain a visible alias/command token, command icon, and one inline text field with a configurable placeholder such as `log_stream`.
- Match the first screenshot's visual hierarchy: command token at the left, argument field beside it, selected command row below.
- Cmd+V, Cmd+A, Cmd+C, Cmd+X, undo/redo, cursor navigation, and input methods work normally.
- Submit the entire field as one argument. Preserve spaces, quotation marks, Unicode, and pasted newlines. Enter submits; do not split or evaluate pasted content as shell source.
- A required argument must contain a non-whitespace character, but validation must not trim the value passed to the process.
- The panel stays open while a script executes and closes on success. Failure appears in its lower section with exit/timeout and stderr (stdout fallback); Edit Input restores the submitted argument without running it. Enter explicitly retries. If the owner dismissed/navigated away, completion must not reopen or overwrite the new view. Hiding for any reason clears failure/input; late completion cannot restore it, and deliberate reopening starts clean. Immediate validation errors stay in the field.

## Settings reference

Use a dedicated settings window with two useful sections: **General** and **Commands**. Within Commands, reproduce the supplied settings screenshot's core structure:

- Top search field; `All`, `Apps`, and `Scripts` filters; a `+` control for adding a script or an application outside indexed roots.
- Table/list columns: real app icon and Name, Type, Alias, Hotkey, Enabled. Group scripts and applications where it improves scanning; use alternating/rounded selected rows and native typography/materials.
- Double-click an application’s Hotkey cell to open an inline recording field; a single click selects the row. An assigned shortcut has a visible × control to remove it in both the cell and inspector. Escape closes the field without saving, preserving the prior shortcut (or unassigned state). Focus loss also cancels; Delete explicitly clears.
- Double-click an Alias cell (or inspector alias) to edit. Enter saves, Escape cancels, and × removes an assignment. Focus/window/cell loss cancels unfinished edits; invalid/duplicate aliases retain the draft and show an error. Select an item to edit its enabled status. Script details include name, path, interpreter, argument toggle/placeholder, result handling, timeout, working directory, and optional environment overrides.
- Commands includes Add Folder, Refresh Scripts and a connected-folders disclosure with disconnect controls. Existing command customizations survive scans; disabling hides a managed script. Refresh on startup and explicit request; direct children only.
- Discovered applications are automatically listed. Disabling hides an app from launcher search without uninstalling or deleting it.
- General prominently starts with launch-at-login, then launcher shortcut status, Keep Awake, Caps Lock → F19, application roots, configuration and recent runs.
- Do not add empty AI, account, cloud-sync, organizations, or other unrelated sections from Raycast.

## Script result contract

- Default `discard` mode: run for side effects; the script can invoke `/usr/bin/open` itself.
- Optional `openURL` mode: on exit code zero, stdout must contain one absolute HTTP(S) URL after removing surrounding whitespace. Open it with the default browser using `NSWorkspace`. Do not open output on failure, on timeout, or when output is malformed/multiple URLs.
- Keep stderr separate from stdout. Present exit status and useful failure text without freezing the launcher.
- A command is an explicitly selected local file/executable, not arbitrary shell source entered into the launcher.
- Existing Raycast scripts have not been supplied. Use generic examples; migrate the owner's real Kibana command when available. The folder importer recognizes title and one required text argument; broader Raycast metadata/import compatibility remains outside v1.

## Deferred features

Shortcuts/Kasa, clipboard history, snippets, file search, window management, calculator, AI, plugin marketplace, cloud sync, multiple argument fields, script-specific global shortcuts, arbitrary key-remapping rules, custom layout-switching engine, arbitrary-layout transliteration, automatic updates, and publishing/notarization.

## End-to-end acceptance

1. Command + Space works globally with either Command key, without Accessibility or Input Monitoring. Check with matching Spotlight/Raycast shortcuts released by the owner during a deliberate manual test.
2. Find an installed app by name or fuzzy query, assign an alias through Settings, restart Uficast, and launch via the saved alias.
3. Create script alias `k`, select it with Tab, paste one text value, and run with Enter. Verify the script receives exactly one unchanged argument and a fixture URL opens in the default browser.
4. Run a shell script and an AppleScript; observe useful handling of a missing executable, nonzero exit, invalid URL, and timeout.
5. Enable Caps Lock → F19, assign F19 to the system input-source shortcut, and test repeated switches between the existing two layouts. Confirm the owner's perceived delay is improved; never infer this from a successful remap alone.
6. Restart the app, sleep/wake, and reconnect a keyboard without losing saved settings or unrelated key mappings. Test relogin/autostart when enabled.

## Owner additions and acceptance

- Opening or reopening the app reveals the launcher; the gear button opens Settings. A second process must exit after notifying the first. Use a durable process-held lock rather than an unreliable PID file.
- App shortcuts use physical key code/modifiers; duplicate combinations are rejected regardless of display labels. While recording, Uficast temporarily releases its own registrations and restores them when recording ends.
- Show/hide means activate/unhide a background app, hide an already active app, and launch a closed app. This applies to the application, not individual windows.
- App icons load on a serial background queue as small bitmap data. Completion updates only the matching existing launcher cell; search, selection and scroll position must remain stable.
- Keep Awake uses a native IOPM idle-display-sleep assertion (which also prevents idle system sleep), off on first installation, with indefinite/30-minute/one-hour sessions. Remember the last active/off state locally across exits; timed sessions resume the remaining deadline or stay off if expired. Show a cup icon while active and a `zzz` sleep icon while off (including startup and decaf mode); with the clock enabled, place this state icon left of the calendar in the same button. Also expose state in the tooltip and menu. Release exactly this app's assertion on stop, expiry or quit. The display stays on during idle use while active. Explicit system/lid sleep behavior remains governed by macOS. This owner clarification supersedes the earlier implementation default that allowed the display to sleep.
- Verify actual login after enabling start-at-login, multiple physical keyboards, reconnect/wake, per-app show/hide cycles and a real idle-sleep session. Record observed outcomes separately from fixture tests.

## Launcher shortcut, display and clock contrast (owner additions, November 19, 2026)

- The launcher shortcut is recorded in General with the same native recorder as app hotkeys. It must contain Command, Control or Option. Escape cancels; Delete or Reset restores Cmd+Space. Older configuration files keep Cmd+Space. App hotkeys may not reuse the effective launcher shortcut, and the launcher may not take an enabled app's shortcut.
- A combination that Uficast cannot register is reported and not saved, so the launcher keeps a working shortcut. Still no Accessibility, Input Monitoring or keyboard observation.
- Display choice uses only window owner, layer and bounds from the system window list; no Screen Recording or Accessibility grant is requested.
- The owner reported that the menu-bar clock is unreadable on an inactive display, where macOS dims the bar. The owner chose an experiment: draw the clock text and icons as one explicit full-contrast image (black on a light bar, white on a dark bar) instead of system-styled template icons and title. On November 19, 2026 the owner confirmed that the clock is readable on an inactive display with this change, so it is kept. Turning off "Displays have separate Spaces" in macOS remains the owner's own alternative; Uficast never changes that setting.

## AI text rewrite and translation (owner addition, November 19, 2026)

Design: `docs/superpowers/specs/2026-11-19-ai-text-rewrite-translate-design.md` (approved).

- Two actions: Rewrite (correct, simple English) and Translate (Russian → English, otherwise → Russian).
- Two entry points:
  - Clipboard: the owner copies text and presses a Uficast shortcut recorded in General. Enter copies the result for Cmd+V.
  - Shortcuts (owner decision, November 20, 2026, replacing the macOS Services entry point, which the owner found useless): Settings has "Create Rewrite Shortcut" and "Create Translate Shortcut". Each opens an empty shortcut in Shortcuts, copies a script for its Run Shell Script action to the clipboard and shows the remaining steps in Settings. The shortcut is a Quick Action that takes the selected text where the app offers it, otherwise the clipboard, and opens `uficast://rewrite?text=…` or `uficast://translate?text=…`. Enter copies the result; nothing replaces the selection, and formatting of a linked text is not kept (plain text only).
  - Both entry points show the result first. Esc cancels without changes.
  - A `uficast://` link only starts a request. Text over 20,000 characters is refused and a link without text uses the clipboard. Observed on November 20, 2026: Shortcuts refuses to import a generated `.shortcut` file ("Importing unsigned shortcut files is not supported") and `shortcuts sign` needs an iCloud sign-in, so the owner builds the shortcut by hand from the steps.
- The command is an owner-editable shell command line. It gets the prompt on stdin and prints only the answer, so the model can be changed by hand or the CLI replaced (for example Codex).
  - Default: `claude -p --model claude-haiku-5-5 --tools "" --strict-mcp-config --disable-slash-commands --no-session-persistence --setting-sources project,local`.
  - The selected text is never placed in argv or shell text.
- Inline formatting (bold, italics, links, fonts and colors of runs) is kept through `<sN>` span markers. If the model breaks them, the result falls back to the selection's base style with a visible note.
- Still no Accessibility, Input Monitoring or synthetic input. Uficast stores no selected text or results; the configured CLI keeps data under its own settings.

## Frequency ordering (owner addition, November 20, 2026)

- The empty launcher search lists applications and commands by how often they were used through Uficast (launcher or an app hotkey that activates the app), then by recency, then by name. Counts are remembered locally across restarts and never include arguments or paths.
- Ordering by frequency does not change the match tiers: an exact alias, then name exact/prefix/substring, then fuzzy always come first, and frequency only orders equal matches. Out of scope: time decay, per-query learning.

## GitHub pull requests (owner addition, November 20, 2026)

Design: `docs/superpowers/specs/2026-11-20-github-pull-requests-design.md` (approved with two owner changes: `gh` is found on `PATH`, and a missing `gh` only shows an install message).

- The owner types `gh` in the launcher, presses Tab (Enter does the same), sees their own open pull requests (newest first), types a few letters to narrow the list by title, and presses Enter to open the pull request in the default browser. The launcher then closes and the browser comes forward.
- The built-in command is named GitHub Pull Requests with default alias `gh`. An explicit user alias `gh` outranks it, as for `cafe`/`decafe`. Unlike `cafe`/`decafe`, the alias matches only exactly: typing `gh` ranks the command first, while `g` alone does not match it by alias (the command can still appear among the matches for `g` through its name, ordered by frequency of use like any other entry). Tab or Enter on the entry only enters the mode and never opens anything.
- The list comes from the GitHub CLI (`gh`) already installed and signed in on the owner's Mac. Uficast does not talk to GitHub, stores no credentials and writes no pull request data (titles, URLs, repositories) to disk, logs or the exported configuration. Only the command's own usage counter is recorded.
- Query: open pull requests authored by the owner across all repositories, at most the 100 newest; drafts are included and labelled "Draft". Uficast sorts: newest first for an empty filter, otherwise fuzzy match on the title (with the same U.S./Russian wrong-layout variants as launcher search) with ties newest first. The filter text never reaches `gh`.
- Escape returns to the normal search with the previous query; Backspace in an empty filter does the same. Hiding the launcher leaves the mode and clears the filter. While loading, typing edits the filter, Enter does nothing and Escape leaves without cancelling the load.
- The first entry runs `gh` (30 s timeout) and shows "Loading pull requests…". A success is kept in memory for 5 minutes, so re-entering shows it at once; after that the next entry loads again. A failure is never cached and never retried automatically: leaving and entering again is the retry. A late result never changes the visible view, reopens the panel or shows an error.
- Messages: a missing `gh` shows "GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login." and nothing is installed or attempted. Other failures show the reason plus the first 512 characters of stderr; an empty list shows "You have no open pull requests." A URL that fails to open shows "Could not open the pull request."
- Still no Accessibility, Input Monitoring or any new permission, no shell string and no launcher text in a command line.
- Documented limitations, not handled:
  - More than 100 open pull requests: the oldest are not listed.
  - `gh`'s default host only. A `GH_HOST` set in a terminal profile is not visible to a GUI app.
  - `gh` is looked up on the app's `PATH` plus the standard directories (`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`). A `gh` that is only in a directory added by a terminal profile (for example `~/.local/bin`) counts as not installed.
  - `gh search prs` uses GitHub's search API: it has search rate limits, and pull requests in organizations that require SSO authorization of the `gh` token may be missing without any error.
  - No manual refresh control; the list is reloaded on the first entry after 5 minutes. The store has an `invalidate()` for a future control.
- Out of scope: other queries (review requested, closed, other authors, per repository), other hosts, checkout/review/merge actions, a general "script prints a list" mode, a Settings page, a persisted cache, notifications.
- Acceptance: a real `gh` run with real pull requests, a signed-out `gh`, the browser opening and the physical Tab/Enter/typing flow are owner-led checks in `docs/MANUAL_TESTS.md`; they are not inferred from fixture tests.

## Calculator (owner addition, November 19, 2026)

- Typing a formula in the launcher search shows its result as the first row. Enter copies the result (dot decimal, at most 15 significant digits) to the clipboard, remembers the calculation and closes the launcher, returning focus to the previous app.
- Supported: `+ - * / ^ %`, `× ÷ −`, parentheses, and `.` or `,` as the decimal separator. `200+10%` and `200-10%` are relative to the left side; otherwise `n%` is `n/100`. Input the evaluator cannot read exactly (incomplete, `1/0`, ambiguous `1,000`, more than 200 characters or 64 nesting levels) shows no result instead of a guess.
- The last 50 distinct calculations are remembered locally (not in the exported configuration). While typing a formula start, or after `calc`, up to six matching entries appear below the results; Enter on one copies its result and Tab moves its expression into the search field. `calc` still lists the Calculator application first.
- An unfinished formula (or `calc` plus text) is restored and selected when the launcher reopens; typing replaces it. Any other search text is still cleared on hide, so this is the one exception to the clear-on-hide rule, and errors/script input are unaffected.
- Out of scope: functions, units, currencies, variables.

## Keyboard conventions (owner additions)

- Settings opens locally with Cmd+, and the owner's additional Cmd+P (macOS normally uses Cmd+P for printing). Esc closes Settings, except that inline alias/hotkey edits consume the first Esc to cancel; script sheets retain their own Cancel behavior.
- Provide standard menu commands: Cmd+W close window/panel, Cmd+F search (Commands in Settings), Cmd+H hide, Option+Cmd+H hide others, Cmd+M minimize Settings and Cmd+Q quit. Preserve normal text editing, undo/redo and focus navigation. No additional global keyboard registrations or input observation.
- Follow Apple's documented conventions where applicable; a launcher has no document printing/opening/tab system to assign those commands to.

## Day-O calendar (owner addition)

- Developed on `codex/day0-calendar-experiment`, branched from `7ebcf04` after the adjacent chat completed; the owner authorized integration into main on November 18, 2026. The owner's screenshots are visual references. The owner explicitly clarified that the upper menu bar is intended and that the clock itself is Uficast's one button.
- Match Day-O using AppKit's standard `NSDatePicker` in `clockAndCalendar` mode, rather than a custom date grid. Preserve native compact sizing, previous/next month controls, Today, selected-date appearance and light/dark behavior. Reset to today on each menu opening. No event/account integration.
- Center the native calendar with equal outer side margins as in Day-O. Omit keyboard-shortcut hints from the status menu to keep it narrow; the existing application-menu shortcuts remain active. Diagnostics, refresh and shortcut retry are in Settings. Keep Awake uses its existing service through a submenu. Add the Date & Time settings entry shown in the reference.
- General offers Date & Time Format and Show Icon. The calendar icon includes the current day. A zzz/cup indicator for the current Keep Awake state appears to its left in the same button; it stays visible when Show Icon hides the calendar. Implementation defaults: clock enabled, icon shown, format `EEE HH:mm:ss`, Monday-first Gregorian calendar with English labels; users may disable the clock to restore the cup/zzz button. Settings persist in the existing versioned configuration, with legacy files decoding defaults.
- Seconds must follow system-second boundaries, rather than an arbitrary one-second interval starting at app launch. Recalculate the next tick from wall time each time and resynchronize on clock/time-zone changes and wake. Actual side-by-side visual timing remains a manual check.
- The owner authorized read-only examination of installed Day-O for matching its design. No Day-O executable, artwork or other bundled asset is copied into the repository or needed at runtime.
