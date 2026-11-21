# Desktop verification

All items are pending unless a dated result is recorded in PROGRESS. No Accessibility or Input Monitoring grants are allowed/required by this app.

## Launcher and focus

- Build with `scripts/build.sh`, launch `dist/Uficast.app`, and find its menu bar icon. Confirm Open Launcher, Settings, registration status, Retry and Quit.
- Open from the menu, type/paste, use Cmd+A/C/X/V/Z and Shift+Cmd+Z, then Escape. No keyboard permission prompt should appear.
- Release matching Spotlight/Raycast shortcuts yourself for this test. Automation must not change these settings.
- Cmd+Space toggles once using either Command key. Holding Space must not repeatedly toggle or insert spaces in the previous app.
- Test both Command keys, extra modifiers, releasing Command before Space, retry, sleep/wake, fullscreen and multiple monitors when available.
- General → Launcher: record another shortcut (for example Ctrl+Space), press it from another app, quit and reopen Uficast, and confirm it persists. Cmd+Space must then be free. Try a combination already used by an enabled app hotkey: it must be rejected. Press Escape while recording: nothing changes. Use Reset (or Delete while recording) to restore Cmd+Space.
- Two displays: focus a window on each display in turn and open the launcher; it must appear on the focused window's display even when the pointer is on the other one. With a windowless app frontmost (for example Finder with no windows), it opens on the pointer's display.
- Escape and outside clicks dismiss; cancellation restores prior focus when appropriate. Opening a destination must let it take focus.
- Record actual Secure Input behavior and known limitations; do not bypass system protection.

- Inactive display: with two displays, focus a window on one display and look at the Uficast clock on the other. Record whether the clock text and icons are readable compared with other menu-bar items. Check both light and dark menu bars and the open-menu highlight.

## Added features

- Opening shows the launcher immediately; reopening while it is running reveals the same process. Click the footer gear to open Settings.
- Observe icons loading in the launcher and Settings without changing selection/scroll or flashing placeholders repeatedly. The offscreen --verify-native-icons regression check covers loaded bitmaps with unchanged row geometry and scroll position.
- In Commands, single-click an app Hotkey cell: it only selects. Double-click the current shortcut or Add Hotkey: an inline recording field opens. Press a bare letter then Escape: no configuration save occurs and the previous shortcut reappears. Repeat on an unassigned app; click outside/change section/close Settings while recording and verify global shortcuts are restored. Record a valid combination, remove with the adjacent × (also in Show / Hide), clear with Delete, and verify duplicate/reserved-chord errors. A background app comes forward, an active app hides, and a closed app launches.
- General starts with the startup checkbox. Check actual Login Items authorization/status and a real relogin after enabling it at the intended stable bundle path.
- For every physical keyboard used, leave macOS Modifier Keys Caps Lock → Caps Lock, enable the Uficast F19 mapping and assign F19 to the input-source shortcut. Test with two keyboards, reconnect and wake; ensure another tool's mappings survive. Quitting Uficast removes only its own mapping.
- A fresh installation starts off; subsequent launches restore the saved caffeine/decaf mode and remaining timer. Test indefinite/timed enable, renewal, expiry and stop; confirm the actual power assertion belongs to Uficast. While active, the owned assertion must be PreventUserIdleDisplaySleep and keep the screen on during idle use. Lid/explicit sleep remain governed by macOS. Never infer real idle-sleep acceptance from a fixture backend.

## Wrong-layout search

- Search for Chrome with `сркщьу` and Firefox with `ашкуащч`, where installed; test `ntktuhfv` against a Russian-named fixture Телеграм.
- Verify a literal exact alias wins over its converted counterpart, and both beat name matches. Check Commands search too.
- Paste mixed-language text into a script argument and verify it arrives unchanged.

## Later-stage acceptance

Follow [requirements](plan/REQUIREMENTS.md). Caps Lock remapping, login items, opening URLs and real script execution require intentional user actions. Automated core tests use fixtures and temporary directories.

## Built-in power commands

- Search caffeine/cafe and decaffeine/decafe; verify Command labels and cup icons. Try cfn/dcfn and Russian physical-key input сфау/вусфау.
- During an owner-initiated power test, run cafe and confirm the menu/Settings state changes to indefinite Keep Awake; repeat without creating extra assertions. Run decafe and confirm that assertion is released. Do not execute a found result just to test search.
- If a user app/script alias is cafe, it remains the preferred alias match; caffeine remains available by full name.

## Script folders

- In Commands, Add Folder (or + → Add Script Folder) opens a directory-only picker. Cancel makes no changes. Connect a fixture directory containing a shell script with a Raycast title and one text argument; it appears immediately and opens argument mode with the expected placeholder. Adding never executes it.
- Refresh after adding/removing files; verify no duplicate commands and retained aliases/enabled/editor options. Restart to verify saved folder discovery. Hidden files and subfolders are skipped.
- An unavailable root reports status and retains records; reconnect/refresh recovers it. Unsupported argument declarations show notices without silently creating a no-argument command.
- Disable a managed script to hide it. Disconnect a folder: its managed commands disappear, manual entries remain and every source file stays intact. Editing a managed path detaches that command.
- Never include private scripts, internal URLs, home paths or real configuration in repository fixtures/screenshots. Test actual private script execution/browser behavior only during an owner-initiated run.

## Alias editing and failed input correction

- Single-click an Alias cell to select its row; double-click to edit. Type a change then Escape: the assigned or empty value remains unchanged. Enter saves exactly once; duplicate/whitespace aliases keep the draft open with an error. Click × to remove. Repeat for apps, scripts and the inspector. Focus loss, section/filter/window changes and reused rows must not save unfinished input.
- In argument mode, compare light/dark and empty/filled states: no opaque white box, matching placeholder/text leading edge and readable selection/caret.
- Run an intentional generic failure with one argument. The launcher stays open during the run and shows the bounded error below. Verify stdout-only failure text too. Edit Input restores spaces/Unicode/newlines exactly and does not run; Enter explicitly retries. Success closes the panel.
- Dismiss/navigate before a slow failure finishes: no reopen or replacement of newer input. Hide by Esc, Cmd+Space, outside click, Settings, Cmd+W or hiding the app; deliberate reopen must show no stale error or Edit Input. Verify concurrent old completions do not replace the latest run's status. Cancellation/quit must not open a URL.
- Native --verify-alias-editor and --verify-script-feedback cover fixture behavior, not private scripts or physical paste/input acceptance.

## Window shortcuts and remembered power state

- Cmd+P and Cmd+, open Settings while Uficast is focused. Esc in ordinary Settings/search closes the window; an alias/hotkey edit consumes the first Esc to cancel without saving, then the next Esc closes. An attached script sheet consumes its Cancel shortcut first.
- Cmd+F focuses/selects search; from General it switches to Commands. Cmd+W closes Settings or launcher, Cmd+M minimizes Settings, Cmd+H hides the app, Option+Cmd+H hides others and Cmd+Q quits normally. Don't invoke hide-others/quit in unrelated apps for verification.
- During an owner-initiated power test: enable caffeine, quit/reopen and confirm active restoration with one fresh owned assertion. Stop, quit/reopen and confirm decaf stays off. A timed session resumes only its remaining time; let it expire while closed and confirm it stays off. Tests use fake assertions, not the actual machine's sleep policy.
- --verify-keyboard-shortcuts checks native menu equivalence, Esc priority and hotkey capture with fixtures and no global registration. Core restoration tests round-trip the saved session and verify release/reacquire/expiry using fake backends.

## AI text

- **Command.** General → AI Text shows the default command. Change the model name, Apply, run a rewrite, then Reset to Default. A wrong model name or a missing CLI shows the error text in the panel. Enter retries; there is no automatic retry.
- **Clipboard.** Record "Rewrite from clipboard" and "Translate from clipboard" shortcuts.
  - In an Electron app (for example Teams or Slack), copy English text, press the rewrite shortcut and check the result. Enter, then Cmd+V pastes it.
  - Repeat with Russian and English text for translate.
  - With an empty clipboard or an image, the panel says "Copy text first."
- **Create Shortcut.** In General → AI Text, click Create Rewrite Shortcut. Shortcuts opens an empty shortcut, the script is on the clipboard and the five steps appear in Settings. Follow them, then repeat for Translate. Note anything in the steps that does not match Shortcuts' real wording.
- **Shortcut run.** Run the shortcut from the Services menu or from its details window. With text selected in Notes or Safari, Uficast shows the result for that text; with nothing selected, for the clipboard. Enter copies it, Esc cancels, nothing replaces the selection. Try a multi-line text with `&`, `+` and Cyrillic characters.
- **Shortcut keyboard shortcut.** Assign one with ⌃⌘⇧ (⌃⌘R was silently taken by another app on the owner's Mac) in the shortcut's details and press it in Notes, Safari and an Electron app. Note where the selection arrives and where the clipboard is used instead.
- **Shortcut hotkey diagnosis.** Press the shortcut's keyboard shortcut (with text selected in Notes, then with only the clipboard), then open Settings and click Recent Runs. "Rewrite link received (N characters)." means the shortcut ran and the link arrived; no such line means the hotkey never ran the shortcut. "The result panel closed because it lost focus." means the panel opened and was closed by a focus change.
- **Links.** `open "uficast://rewrite?text=we%20was%20here"` shows the panel with a result; a link with more than 20,000 characters shows "The text is too long". Opening a link must not copy anything until Enter.
- **Old Services.** After the update the old "Rewrite with Uficast" Services entries may linger in the Services menu until `/System/Library/CoreServices/pbs -update` or a new login; they no longer do anything.
- **Formatting.** Select text that contains bold, italics and a link, copy it and use the clipboard shortcut, then paste into Mail. The bold and link are kept. Text that arrives through a Shortcut link is plain.
- **Codex.** If Codex is installed, enter its command and check that only the answer appears.

## GitHub pull requests

Owner-led. Quit Uficast normally before installing the build. The not-installed message is covered by unit tests only; it is not on this list because it needs `gh` to be absent from the app's `PATH`.

- [ ] With the real `gh` signed in and a few real open pull requests: type `gh`, press Tab. After "Loading pull requests…" the list shows your open pull requests, newest first, each with its repository and number, and drafts marked "Draft".
- [ ] Type a few letters of a title: the list narrows by fuzzy match and the first row is selected. Type a Russian-layout version of the same letters: the same rows appear. Up/Down move the selection.
- [ ] Press Enter on a row: the pull request opens in the default browser, the launcher closes and the browser comes forward. Check that it is the selected one.
- [ ] Sign `gh` out (`gh auth logout`, owner-initiated) and enter the mode after the 5-minute lifetime has passed or after a relaunch: the lower area shows a failure text, not a frozen launcher. Sign in again; leaving and entering the mode retries. There must be no automatic retry.
- [ ] First Tab latency: note how long the first load takes with the real `gh`, and that a second entry within 5 minutes shows the list at once.
- [ ] Wait more than 5 minutes (leave Uficast running), open a new pull request on the web, then enter the mode again: the new pull request appears after the reload.
- [ ] Press Tab and Enter on `gh` while Keep Awake is active and while it is off: its state, the cup/zzz icon and any assertion never change.
- [ ] Esc returns to the normal search with the previous query; Backspace in an empty filter does the same; Esc in normal search closes the launcher. Hide the launcher while it is loading, reopen it: no stale list, error or mode is shown.
- [ ] Look at the mode in light and dark appearance: the token, filter field, rows (title, dim `owner/repo #number`, Draft label), loading text and hint are aligned and readable. Note anything cramped.
- [ ] Native `--verify-pull-requests` uses fixtures and a fake opener; it does not prove the real `gh`, the browser, the physical typing flow or the on-screen layout.

## Compact settings

- [ ] Open Settings → General: everything fits without scrolling at the default size. Make the window smaller: it scrolls only when it must.
- [ ] Every ⓘ opens its explanation. Recent Runs in the footer lists active runs with Cancel and the latest outcomes.
- [ ] Each control still works as before: start at login, launcher shortcut record/reset/retry, clock toggles/format/Apply/Reset, Keep Awake and its timers, Caps Lock mapping and Check Mapping, AI command Apply/reset, both clipboard hotkeys with ×, folders Save/Refresh, Import/Export/Restore.
- [ ] Create Rewrite Shortcut opens Shortcuts and a sheet with the five steps; Done and Esc close the sheet.
- [ ] Check light and dark appearance and note anything cramped.

## Calculator

- [ ] Type `2+2*3`: the first row shows `= 8`. Enter closes the launcher, focus returns to the previous app and Cmd+V pastes `8`.
- [ ] Type `200+10%` (220), `1,5*2` (3), `(1+2)*3` (9). `1/0`, `2+` and `1,000+1` show no result row.
- [ ] Open the launcher and type `calc`: the Calculator app is first and earlier calculations are listed below. Type the start of an earlier formula: it appears below the live result. Enter on it copies its result; Tab moves its expression into the field.
- [ ] Type `7*`, press Esc and reopen: `7*` is back and selected. Typing `notes` replaces it; after closing with `notes` typed, the launcher reopens empty. Quit and relaunch with an unfinished formula: it is restored.
- [ ] `1password`, `7-zip` and `calendar` still behave as application searches.
- [ ] Native `--verify-calculator` uses a private pasteboard and fixtures; it does not prove physical typing or paste into another app.

## Frequency ordering

- [ ] Launch two different apps from the launcher, one of them three times. Quit and reopen Uficast: the empty search lists the three-time app first, then the other, then the rest alphabetically.
- [ ] Type a short prefix shared by two apps: the more used one comes first. An exact alias still beats a heavily used app.
- [ ] Activate a running app with its app hotkey a few times; it moves up the empty list. Hiding it does not count.
- [ ] Native `--verify-usage-order` uses fixtures and a second controller to stand in for a restart; it does not prove the real relaunch.

## Day-O calendar experiment

- [ ] Compare the installed experiment with Day-O: one Uficast clock button, compact menu width, native calendar typography/arrows/selection, and light/dark appearance.
- [ ] Click previous/next repeatedly across a year boundary, click Today, dismiss and reopen; native navigation works and reopening returns to today.
- [ ] Observe the seconds beside the system clock for at least a minute, including while browsing the menu. Repeat after wake and an owner-initiated time-zone change; do not change the system clock merely for verification.
- [ ] Change the format and Show Icon, reopen/restart and confirm persistence; disabling the clock restores the cup/zzz button. Restore the owner's chosen preferences.
- [ ] Check Open Launcher, Settings, Date & Time, Keep Awake submenu and Quit; actual power changes remain part of the owner-led power test.
