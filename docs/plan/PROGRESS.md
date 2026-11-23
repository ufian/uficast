# Progress and handoff

Last updated: November 20, 2026 (America/Los_Angeles).

## Current state

Requested personal-use features through Stage 6k are implemented; Stage 6l is integrated into main at the owner’s request, with remaining manual acceptance pending. Mandatory: ordinary Cmd+Space (either Command key), no Accessibility or Input Monitoring requirement/request. English UI and repository documents. Implementation checkpoint 69b1310 and README checkpoint 2db8863 were committed and pushed to origin/main. Feature checkpoint 0dfeda7 (inline hotkeys and built-in commands) is also pushed. Decaf icon checkpoint c362fdf is pushed. Script-folder checkpoint dae22c0 is pushed. Alias/error UX checkpoint c50f480 is pushed. Window-shortcut/power checkpoint 7ebcf04 is pushed to origin/main. The calendar increment was developed on codex/day0-calendar-experiment and has now been fast-forward merged into main through 72d765c at the owner’s explicit request. Stage 6m (configurable launcher shortcut, focus-display placement and a clock-contrast experiment) is implemented on main and awaits the owner's hands-on checks. Stage 6n (AI text rewrite and translation) is implemented on branch `feat/ai-text` and awaits review and the owner's checks. Stage 6s (the built-in `gh` GitHub pull requests command) is implemented on main and awaits the owner's manual acceptance.

| Stage | State | Evidence / remaining work |
| --- | --- | --- |
| 0 — Plan | Complete | Requirements, architecture and resumable stages committed. |
| 1–3 — Native launcher, catalog, aliases/settings | Implemented | Packaged desktop launch, settings navigation and icons observed. Broader shortcut/focus acceptance remains pending. |
| 4–5 — Scripts, inline argument and URL contract | Implemented | Exact-argv, subprocess, timeout/cancel and URL fixture tests pass; private script/browser workflow still pending. |
| 6 — Caps Lock and login | Implemented; Caps owner-confirmed | Owner confirmed physical Caps switches layouts after correcting a conflicting system modifier assignment. Relogin/multiple physical keyboards remain pending. |
| 6b — Keep Awake | Implemented; display behavior corrected | Native display-sleep assertion now also keeps the screen on. 51 core tests pass; live assertion/restored active state observed. Long idle acceptance remains pending. |
| 6c — Lifecycle, app shortcuts and icons | Implemented | Real startup/gear/singleton and launcher/Settings icon observations; core shortcut/lock fixtures pass. |
| 6d — Wrong-layout search | Implemented | Both U.S./Russian directions, alias ordering, mixed input and ё/й fixtures pass. |
| 6e — Inline hotkey editing/removal | Implemented | Native fixture checks pass; actual Settings double-click and Escape observed without saving an assignment. Assigned shortcuts have × controls in the cell and inspector. |
| 6f — Built-in caffeine commands | Implemented | caffeine/cafe and decaffeine/decafe reuse Keep Awake; fuzzy, layout and alias-precedence fixtures pass. Both abbreviations found in the actual launcher. |
| 6g — Script folders | Implemented | 47 core tests pass; actual directory picker connected the owner-supplied folder and imported seven scripts. Title/interpreter/text argument verified without execution. |
| 6h — Inline aliases | Implemented | Native app/script alias save, Escape, duplicate validation, removal and draft cleanup checks pass; real Settings exposes inline fields and crosses. |
| 6i — Argument styling and failure correction | Implemented | Appearance previews checked; 48 core tests plus native feedback tests pass. Private-script failure/browser flow remains owner-led. |
| 6j — Window keyboard conventions | Implemented | Native menu/Esc-priority checks pass; desktop Cmd+P and Cmd+, opened Settings. Broader physical focus/minimize/hide acceptance remains pending. |
| 6k — Remembered caffeine / transient errors | Implemented | 50 core tests pass with fake power restoration; native feedback check confirms hide clears retained errors and rejects late completion. |
| 6l — Day-O calendar | Integrated into main by owner request | 51 core tests and native clock/menu-mode checks pass; compact NSDatePicker previews inspected. Real menu navigation, side-by-side seconds and preference persistence acceptance pending. |
| 6m — Launcher shortcut, focus display, clock contrast | Implemented; clock owner-confirmed | 57 core tests, six native checks and light/dark previews pass. Owner confirmed the clock is readable on an inactive display. Physical shortcut delivery and two-display placement are not yet observed. |
| 6n — AI text rewrite and translation | Implemented and merged; owner reported it works | 78 core tests and `--verify-ai-text` (fakes, private pasteboards) pass. Real Services replacement, formatting in Mail/Notes and clipboard use in Electron apps are not yet observed. |
| 6o — Calculator | Implemented and merged into main (fast-forward) at the owner's request; installed locally | 93 core tests and `--verify-calculator` (private pasteboard) pass. Physical typing, paste into another app and relaunch persistence not yet observed by the owner. |
| 6p — Persistent frequency ordering | Implemented and merged into main (fast-forward) at the owner's request; installed locally | 99 core tests and `--verify-usage-order` pass. Real relaunch ordering not yet observed by the owner. |
| 6q — Shortcuts instead of Services | Implemented on main; file import failed, replaced by guided manual steps; owner reported it works | 107 core tests and `--verify-ai-text` pass. Shortcuts refused the generated file as unsigned. The owner built the shortcut by hand and it works from Cmd+Ctrl+Shift+R (Ctrl+Cmd+R did nothing). Selection input in each app and Electron apps are not individually reported. |
| 6r — Compact settings | Implemented on main; installed locally; owner look pending | 107 core tests and all native checks pass; light/dark previews inspected. Hands-on use not yet reported. |
| 6s — GitHub pull requests | Implemented on main; manual acceptance pending | 136 core tests and `--verify-pull-requests` pass (fake `gh`, fake clock, fixtures). A real `gh` run, the browser opening and the physical Tab/Enter flow are not yet observed. |
| 7 — Daily-use handoff | Partial | README guide, three neutral screenshots and source-only release build/signature verification complete. Hands-on evidence gaps remain. Manual evidence gaps listed below. |

## Implementation map

- Originally Swift 6.2.3 / macOS 26.6.2 arm64 with Command Line Tools; no external packages or full Xcode required. Since an update the machine has Swift 6.4, macOS 26.7.3 and a default MacOSX27.0 SDK; see the Stage 6m toolchain note. `scripts/build.sh` creates an ad-hoc signed app; `UFICAST_OUTPUT_ROOT` isolates output. Quit before replacing a running bundle.
- Carbon RegisterEventHotKey handles the configurable launcher shortcut (default Cmd+Space) and configurable app bindings. Local recorder releases/restores Uficast registrations; duplicate/reserved chords are rejected. Native NSRunningApplication activate/hide/unhide launches closed apps without AX.
- InstanceLock uses process-held flock, never unlinks its inode, and InstanceCoordinator reveals the primary process via a user-scoped distributed notification. Ordinary launch/reopen reveals the panel; footer gear opens Settings.
- ApplicationCatalog discovers configured roots in the background. SearchIndex preserves exact-alias priority and stable ranking/history. KeyboardLayoutSearch expands queries using U.S./Russian physical keys before folding diacritics; literal variants win ties. Arguments and visible input remain unchanged.
- ConfigStore validates versioned private JSON, writes atomically, protects corrupt/future files and maintains recoverable backups. Optional app hotkeys and default-off Caps preference decode existing schema-1 files. Never commit personal config.
- ScriptRunner wraps the C posix_spawn/poll process-group worker: exact argv, one unchanged argument, concurrent bounded pipe draining, cancellation/timeout and managed descendant cleanup. Strict single HTTP(S) stdout URL opens only after success. Deliberately detached daemons are outside cleanup guarantees.
- IconStore serially renders 64px PNGs, transfers Data across actors and retains a bounded 256-image cache. Each launcher EntryRow receives its own guarded completion; no icon-triggered table reload. Settings observes cache updates.
- Caps ownership/recovery preserves unrelated/external mappings. Device/service lifecycle and wake re-publish owned mappings without observing input. ModifierMappingDiagnostics detects macOS Caps modifier conflicts across keyboard profiles without automatically rewriting them.
- Native SMAppService startup checkbox is at the top of General and shows actual authorization state. KeepAwakeService owns one IOPM idle-display-sleep assertion (also preventing idle system sleep), supports timed/indefinite renewal and releases on stop/quit. The app restores the last local mode/deadline; a fresh installation starts off.

## Actual verification

- `scripts/test.sh`: **42 tests passed**, including built-in caffeine command search, wrong-layout search, shortcuts, configuration, singleton lock, remap ownership, keyboard profiles, power fixtures and real shell/AppleScript argument/process tests. Warm search over 2,000 synthetic apps: debug p95 **19.92 ms**, target below 30 ms.
- Current isolated release build (`UFICAST_OUTPUT_ROOT="$PWD/.build/release-check" scripts/build.sh`) and strict ad-hoc signature checks passed, including wrong-layout changes. The native 50-icon check also passed on that release.
- Native `--verify-native-icons` passed for 50 actual catalog entries after the direct-completion fix. Checks loaded bitmap representations, row geometry and scroll origin, not AppKit's offscreen view-cache identity.
- Desktop: canonical `dist/Uficast.app` launched with the panel immediately; gear opened Settings, real icons appeared in Settings and later in launcher. The latest icon fix was verified in the actual running canonical app. Opening a second copy exited and revealed the original process.
- Owner enabled startup/Caps controls. A conflicting macOS Modifier Keys assignment mapped Caps Lock to Right Option despite correct hidutil tables. During the authorized setup, the current keyboard's Caps assignment was restored to Caps Lock, keeping the F19 input-source shortcut. Owner then explicitly confirmed physical Caps switches layouts while Uficast runs. No latency measurement or multi-keyboard acceptance is claimed.
- No Accessibility/Input Monitoring grants requested or enabled. No keyboard events are monitored. Automated mapping, login and Keep Awake tests use fixtures and do not change actual settings/assertions.
- Offscreen fixture previews verify layout only; they do not establish actual keyboard delivery, paste, focus or browser operation.

## Remaining manual/platform checks

- Launcher shortcut (default and a custom one) repeat/release and system conflict behavior, two-display focus placement, clock readability on an inactive display, Secure Input, fullscreen/multiple monitors, editing/paste/focus across destinations and sleep/wake.
- App show/hide/closed-launch cycles with physical assigned shortcuts; persistence/restart acceptance.
- Owner's real script/environment and full paste → script → browser flow; Automation consent across ad-hoc rebuilds.
- Actual relogin at the stable app path, multiple physical keyboards/reconnect/wake, preservation under external mapping changes and perceived switching latency.
- Real timed/indefinite idle-sleep prevention, expiry and stop (fake-backend tests are not sleep acceptance).
- Other Macs, Intel and older macOS versions have not been tested.

## README and repository delivery

- Implementation checkpoint **69b1310** is pushed to origin/main. SSH authentication had no key; push used existing `gh` HTTPS credentials with command-scoped URL rewriting/helper, without changing the remote/global configuration. Configured 1Password signing was unavailable, so the commit used command-scoped `commit.gpgsign=false`; no global setting changed.
- README now describes features, build/run, configuration, scripts and keyboard setup, with three actual native-view screenshots: standard-app launcher, Commands with example aliases/hotkey, and dark argument mode. Images were visually inspected; no personal data, internal URLs, home paths or desktop content is shown.
- `ViewPreview` owns hard-coded Calculator/Calendar/Notes/Safari/Terminal and generic Search Example fixtures. Preview paths do not construct AppController, discover installed apps, read personal config, register hotkeys or change mappings/login/power state. `scripts/screenshots.sh [bundle.app]` reproduces the PNGs under `docs/screenshots/`.
- Screenshot review exposed and fixed an empty-query regression in Settings: blank/whitespace search now retains all entries. The final Commands capture visibly includes all six fixture commands and their icons/aliases.
- Current preview release build and strict signature check passed. A separate source-only snapshot (without Git metadata, caches or private configuration) also built successfully using the documented `scripts/build.sh`, including strict signature verification. All relative Markdown file/image links resolve; shell syntax and diff whitespace checks passed. Native screenshots verify layout, not physical input.

The README checkpoint **2db8863** is pushed. The canonical `dist/Uficast.app` has now been rebuilt after a normal Quit and reopened with the latest inline recorder, removal controls and built-in commands; no running executable was overwritten. The older source-only build evidence above applies to the README checkpoint, not a fresh snapshot of this increment.

## Current increment: inline hotkeys and built-in commands

- Double-click an application's Hotkey cell (assigned or Add Hotkey) to show the native recording field. A single click selects the row. Escape never invokes the save callback; a valid chord commits and Delete explicitly clears. A visible × removes an assignment from both the cell and Show / Hide inspector.
- Recording releases Uficast's own registrations only while active, and restores them on Escape, capture, focus loss, window deactivation/close and cell removal. No global input observation or privacy grants were added. Existing duplicate/reserved validation stays in place.
- `--verify-shortcut-recorder` passes against real hosted Settings cells using synthetic local responder events and in-memory public fixtures: single/double click, invalid bare key, Escape retaining assigned/unassigned values, exactly one capture, explicit clear and balanced lifecycle cleanup. It does not save personal config or register actual global shortcuts.
- Desktop: double-clicking an actual Hotkey cell visibly showed Press shortcut…; Escape restored Add Hotkey. The canonical app was rebuilt again with × controls and commands; searches cafe and decafe visibly selected caffeine and decaffeine respectively. These results were inspected without executing a command or assigning/removing a personal hotkey.
- BuiltInCommand appends stable command entries to launcher search, with cafe/decafe aliases and cup icons. Execution routes directly to the shared native power service: enable indefinitely / disable. Explicit user aliases override conflicting abbreviations. Built-ins are not stored as editable script/app records.
- Current release build and strict signature verification passed; the native recorder check passed on that final bundle. **42 core tests passed**, including exact/abbreviated/fuzzy/wrong-layout built-in searches and alias precedence. Real power effects remain covered by the existing manual acceptance gap, not inferred from search.
- README/requirements/architecture/stages/manual checklist updated. The Commands screenshot was regenerated from public fixtures and visually inspected: real standard-app icons and × controls appear in both places, with no personal data.

## Decaf icon polish

- Owner requested a sleep zzz icon in decaf mode. The status item now uses SF Symbol `zzz` both at initial startup and whenever Keep Awake is inactive; active sessions keep the filled cup. Inactive accessibility text explicitly says Keep Awake off. The decaffeine launcher command also uses zzz.
- `scripts/build.sh` passed release compilation and strict signature verification. The canonical app was normally quit before replacing its bundle and successfully reopened. Its AX tree recognized the decaffeine symbol as Snooze. The menu bar appearance itself was not separately captured, and no power session was toggled for verification.
- No power logic or configuration changed. Existing 42-test results are from the preceding feature checkpoint; the suite was not rerun for this symbol-only edit. README, requirements, architecture and the plan were updated.

## Script-folder increment

- Owner requested adding a scripts folder directly in UX after supplying a local shell-script path. Commands now offers Add Folder and Refresh Scripts, also + → Add Script Folder. Connected folders can be disconnected with × without deleting source files. Folder-managed commands can be disabled and edited; individual Delete is disabled while managed.
- Configuration schema 1 gains default-empty scriptDirectories and optional ScriptCommand.sourceDirectory. Existing configurations decode unchanged. Scans run off the UI actor, read direct non-hidden regular files, canonicalize/deduplicate paths, and read at most 32 KiB of headers. No imported script is executed or copied. Scripts remain linked to original paths.
- First import recognizes known shell/Python/AppleScript extensions and shebangs, Raycast title and one required text argument/placeholder. Unsupported argument declarations produce notices. Existing IDs, aliases, enabled state and edited options are retained; manual file references are not duplicated. Unavailable roots retain commands; missing files are pruned only from successfully read roots. Changing a managed path detaches it with a new ID. Refresh runs on startup, explicit request and directory changes through import/recovery; no live watcher or recursive scan is claimed.
- **47 core tests passed**, including five new folder/metadata/lifecycle/compatibility fixtures. Tests establish discovery has no script side effects. Current warm-search p95: **19.39 ms** over 2,000 synthetic apps. The existing native inline-recorder check also passed with the new folder controls in Settings.
- Isolated and canonical release builds and strict signature verification passed. Canonical app was normally quit before rebuilding, then reopened. Desktop Add Folder opened a directory-only native picker; the owner-supplied parent folder was connected and the UI reported seven found scripts. Scripts filter showed the imported commands. Inspecting the supplied command showed the imported title, /bin/bash interpreter, required text argument, expected placeholder and side-effect result mode. The editor was cancelled without changes; no imported script/browser action ran. Personal paths, source contents and internal URLs are absent from repository fixtures/docs/screenshots.
- README, architecture, requirements, stages and manual checklist document direct-child discovery, refresh behavior, metadata limits and disconnect semantics. The Commands screenshot is regenerated from the same public standard-app fixture dataset; actual personal Settings are never used for README captures.

## Alias, argument appearance and failure-feedback increment

- Owner requested the Alias column behave like Hotkey: double-click to edit, Escape to discard and × to remove. AliasEditor now supplies native label/field/remove controls in the table and inspector. Enter validates/saves; duplicate/invalid values keep the draft. Focus/window/filter/reuse/disabling cancels without saving. The old inspector Apply flow is removed. Public fixture app identities now use valid app: IDs so checks exercise actual config validation.
- Native `--verify-alias-editor` passes app/script edits, assigned/unassigned values, single/double click, Escape, duplicate rejection, exact save counts, cross removal, hotkey/argument-option preservation and draft cleanup. `--verify-shortcut-recorder` also passed after the table changes. Real Settings showed the assigned alias with its cross and opened the inline text field on double-click; no test alias was saved to personal config. The user changed the app during further inspection, so additional live interaction stopped. An extra native check confirms editing survives selection/layout of a previously unselected row; the offscreen harness emitted SwiftUI AttributeGraph cycle diagnostics while exercising selection/model updates, although all behavior assertions passed. Check for recurrence during daily use; no such diagnostic-driven UI failure was established.
- Argument scroll/clip backgrounds are transparent; a subtle semantic fill replaces the opaque white field. Text/placeholder insets align. Empty/filled light/dark native previews were rendered and visually inspected, plus the updated failure view. The formatting fix was installed; no private argument was submitted during verification.
- Scripts now retain their current launcher view during execution. Success closes that presentation; failure shows a lower error block and Edit Input. The last failure/exact argument is held only in memory. Edit Input restores/selects the original string and never executes; Enter explicitly retries. Presentation IDs prevent stale completion from replacing newer search/input or reopening a dismissed panel. The latest failure can be offered on a deliberate reopen.
- ScriptResult.failureDescription reports exit/timeout and bounded stderr, with stdout fallback when stderr is empty. **48 core tests passed**, including real generic stdout-only failure and stderr precedence; latest warm-search p95 **19.11 ms** over 2,000 synthetic apps. `--verify-script-feedback` passed duplicate-run UI guards, exact argument restoration, explicit retry, success cleanup, no-input errors and stale-result handling with injected completions. No private scripts, browser actions or power assertions were triggered for these checks.
- Isolated and canonical release builds/signature checks passed. Canonical app was normally quit before rebuilding and reopened with the features. README requirements/architecture/stages/manual checklist updated; four screenshots are generated from public fixtures only, including a generic failure. Development previews support --empty-argument / --failure; script-feedback checks bypass normal lifecycle/configuration/registrations.

## Window shortcuts, remembered caffeine and clear-on-hide increment

- Owner requested Esc to close Settings, Cmd+P to open it, a review of conventional macOS shortcuts, remembering caffeine across exits, and clearing the launcher error as soon as the window is hidden for any reason.
- Reviewed primary Apple sources: standard Settings is Cmd+,; Cmd+P normally prints and is an explicit owner-specific Settings alias here. AppMenu now exposes native File/Edit/Window/application commands for Cmd+W, Cmd+F, Cmd+H, Option+Cmd+H, Cmd+M, Cmd+Q and existing text editing. These are local; no added global registrations or input observation. Cmd+F routes to the current launcher or Commands search in Settings. Hidden apps can reveal the launcher again.
- SettingsWindow handles window-local Esc: attached sheets retain their own Cancel flow, active alias/hotkey editors cancel first without saving, otherwise Settings closes. --verify-keyboard-shortcuts passed real NSMenu dispatch for Cmd+,/Cmd+P/Find, native Esc precedence and recording Cmd+P without invoking Settings. The delegate also clears launcher state when the app hides.
- SavedKeepAwakeSession stores active/off and optional expiry in local UserDefaults key keepAwakeSession.v1, outside config import/export. Startup restores indefinite or remaining timed sessions and leaves expired/off sessions inactive. Initial observer notifications cannot erase the saved state before restoration. Quit snapshots before releasing its assertion and suppresses cleanup persistence. This supersedes the earlier default-off-on-every-launch requirement; first installation remains off.
- **50 core tests passed**, including fake-backend release/reacquire, off-state round trip, timed remaining duration and expiry while closed. Warm 2,000-app search p95 **20.24 ms**. Actual active-mode relaunch/idle-sleep acceptance remains owner-led; no real power session was enabled just to verify this code.
- Hiding now clears the argument, error/action/hint state and both presentation IDs even if the panel has already become invisible. finishScriptRun checks the current IDs before remembering an error, so late results cannot restore it. Deliberate reopening is clean. --verify-script-feedback passed the added hide/late-result regression. This supersedes the earlier offer-last-failure-on-reopen behavior.
- Isolated/canonical release builds and strict signature checks passed. After a normal Quit, the canonical dist app reopened with new menus and no stale error. Desktop Cmd+P and Cmd+, opened Settings; an Esc interaction returned to the launcher. A later Cmd+F automation interaction focused the launcher rather than confirming Commands search; physical Settings focus/hide/minimize acceptance remains on the checklist. General displayed the new remembered-mode guidance and off state; no private scripts or power toggles were executed by the agent.
- README now has a keyboard shortcut table with Apple references; requirements/architecture/stages/manual checks were updated. Existing public screenshots remain representative; no private screenshot/configuration/defaults are committed.

Stage 6l owner-requested calendar work is recorded below; the earlier daily-use acceptance gaps remain pending.


## Day-O calendar experiment

- Waited for adjacent project chat to complete and publish 7ebcf04, confirmed a clean tree, then created `codex/day0-calendar-experiment`. The owner clarified upper menu bar only and that the clock itself must be Uficast's single button. No extra Dock icon or second permanent status item.
- Added General Date & Time Format, Apply/Enter, Reset, live preview, Show Icon and optional clock-off fallback. Schema-1 menuBarClock defaults preserve loading older configurations. The owner’s existing startup checkbox remains at the top. No personal configuration was edited by the verification fixtures.
- The first custom-grid implementation was installed. The owner's screenshot identified an oversized root menu and mismatched calendar. With explicit authorization, read-only inspection of installed Day-O 3.0.1 revealed its standard NSDatePicker. Replaced the custom grid with that native clockAndCalendar control; no custom date-arithmetic model remains. The native picker is 139×148 pt; the padded menu view is 163×164 pt. Fixed-date July 2027 light/dark previews were rendered and visually inspected. No Day-O assets/code were copied; no calendar event access.
- Root menu now contains the calendar, Open Launcher, Settings, Date & Time, Keep Awake submenu and Quit. Long shortcut/action diagnostics no longer stretch it: shortcut retry, refresh and diagnostics stay in General; the latest action/error is in General / Recent Runs. Keep Awake keeps its shared service and timed controls.
- Owner reported seconds out of phase with the system clock. Replaced the launch-relative repeating timer with a fresh one-shot deadline at each next integral system second, zero tolerance, common/menu-tracking modes. Wake and clock/locale/time-zone notifications resynchronize. Native --verify-menu-clock passed icon/fallback preferences, native picker/sizing, today reset, synthetic clock-change handling and three observed actual menu-tracking tick phases of **36, 5 and 5 ms** after the second boundary. No system time was changed. This is measured idle-loop evidence, not a guarantee under main-thread stalls or a physical side-by-side observation.
- **51 core tests passed** with scripts/test.sh --disable-sandbox, including legacy decode, preference round trip and format limits. Warm search p95 **22.95 ms** over 2,000 fixtures. The earlier 53-test run covered the abandoned custom date grid; it does not describe the final implementation. SwiftPM nested sandboxing was unavailable here, so release builds used approved unsandboxed execution; no machine-wide preference was changed.
- Isolated and final canonical release builds and strict ad-hoc signature checks passed. The running app was normally quit before each canonical bundle replacement and reopened through the desktop tool. The final canonical app is running with the native calendar and aligned timer. Desktop tooling could inspect the launcher but could not access the status extra; do not mark actual native menu-arrow clicks, one-minute side-by-side timing, format/Show Icon persistence across restart, Date & Time navigation or wake behavior as passed. No private scripts, actual power toggles, login/hotkey/privacy changes or new test mappings were performed.
- Requirements/architecture/implementation plan/README/manual checklist and AGENTS continuity updated in English. No private paths, Day-O resources, build outputs or personal screenshots added to Git.

### Calendar margins and icon polish

- Owner supplied actual Uficast/Day-O screenshots showing asymmetric calendar margins, requested omitting shortcut hints to reduce menu width, and requested Day-O's date icon. The Day-O reference has equal outer calendar margins.
- Removed status-menu Settings/Quit key equivalents; the application's existing menu shortcuts are unchanged. NSDatePicker keeps its native size and now has flexible left/right margins so NSMenu width changes center it rather than leaving it pinned left.
- With the owner's prior permission, inspected Day-O's vector icon and drawing constants read-only. Recreated the 22×18-point frame, three rounded bindings, 2-point image-side padding and 9-point bold date at y=3 using native vector drawing. No resource/binary was copied into the repository; Day-O remains untouched.
- A temporary native public-fixture preview measured picker margins at widths 163 and 192 points: 12/12.5 and 26.5/27 points respectively (0.5-point backing alignment). The centered calendar and enlarged icon were rendered and visually inspected. The temporary preview script initially failed actor isolation, then ran successfully on MainActor; it is not added to the repository.
- Isolated/canonical release builds and strict signature checks passed. --verify-menu-clock passed icon/fallback behavior, native calendar checks and tick phases **36, 4 and 7 ms**. No core model/search/runner behavior changed; the prior 51-test suite result remains the latest full run, not a newly repeated run.
- After normal Quit, the canonical app was rebuilt and reopened through the desktop tool. Actual final menu margins/icon comparison remains owner-led because the tool cannot access the status extra. No private config, hotkeys/login/privacy settings, scripts or power mode were changed for verification.

### Real menu centering and power indicator

- The owner's subsequent screenshot disproved the flexible-margin fix from ac85c08: the actual menu still placed the calendar left of center. The earlier isolated-view preview was insufficient to establish actual NSMenu placement.
- Replaced autoresizing-mask centering with explicit layout/frame-size positioning relative to the real menu window content center, converted into the custom item's coordinates. Kept the native picker size.
- Added --preview-calendar-menu, an isolated interactive native NSMenu fixture with public labels and no AppController/private config/keyboard/login/power services. Its real opened menu measured exactly **12.25 / 12.25 pt** at 163 pt wide, then **25.75 / 25.75 pt** with a 190 pt minimum width. The complete widened menu was opened through the desktop tool and its screenshot visually inspected with equal margins. The initial desktop connection hung/expired; resetting the tool restored it. The fixture was normally quit afterward.
- Owner requested the zzz/cup state symbol left of the calendar. The single status button now composes that indicator with the optional calendar. Show Icon hides only the calendar; clock-off also keeps the power symbol. Icon caching includes active state as well as day, so changes update immediately without waiting for midnight. The symbols preserve their aspect ratio.
- The updated native --verify-menu-clock passed combined-icon width, hidden-calendar indicator retention, injected active-state icon replacement, native calendar and clock checks. No real power session was enabled. Core preferences/search/runner behavior is unchanged; the existing 51-test suite remains the latest full core run.
- Isolated and final canonical release builds/strict signature checks passed. The canonical app was normally quit before replacement and reopened through the desktop tool with the changes. The actual production status extra remains unavailable to that tool; fixture menu centering is now observed, while the owner’s final status-menu comparison remains pending. No private data or configuration, actual hotkey/login/privacy settings or power toggles were changed.
### Caffeine report: read-only diagnosis

- Owner reported that caffeine seemed not to work. Read-only pmset -g assertions showed a live Uficast-owned PreventUserIdleSystemSleep assertion named Uficast Keep Awake. General showed Keep Mac awake checked, Awake until stopped and Keep Awake enabled with no error. This establishes current activation/ownership, not a completed idle-sleep acceptance session.
- Did not enable/disable a real assertion or change the owner's power mode. A temporary native fixture rendered both composite status icons; the cup/zzz and calendar were visible in both states. No app code change or rebuild was justified by these observations.
- Owner clarified that the Mac seemed to sleep despite activation, then said it might already be resolved. No power-mechanism fix was made or claimed. The current service intentionally allows display sleep and does not override explicit Sleep/lid policy. If automatic system sleep recurs, collect the approximate time and read the system sleep-reason log.

### Main integration

- Owner explicitly requested merging and pushing the experiment. Verified origin HEAD points to main at 7ebcf04, fetched origin and confirmed local/remote main had no divergence. The working tree was clean.
- Fast-forward merged codex/day0-calendar-experiment into main through 72d765c, retaining all four experiment commits without conflicts or rewriting history. Reviewed the changed-file list and diff whitespace; no build output, personal configuration, Day-O resources or private screenshots are included.
- Updated README and continuity documents to reflect approved integration. Existing release/signature, 51-core-test and native menu/clock evidence applies to the unchanged implementation; no redundant build/test or app restart was needed for this merge/documentation-only step. Manual acceptance gaps remain open.
- Integration checkpoint **9d0f615** was successfully pushed to origin/main; local HEAD and origin/main matched afterward. Publication used existing gh HTTPS credentials via command-scoped settings, without changing the configured remote/global Git settings. The source experiment branch is retained.

### Caffeine display-sleep correction

- Owner clarified the symptom: the screen turns off while caffeine is enabled, and asked to continue checking. Read-only pmset showed Uficast owned PreventUserIdleSystemSleep while PreventUserIdleDisplaySleep was 0. The earlier activation check established system-sleep blocking only; it did not establish screen-on behavior.
- Verified the distinction in the installed IOPMLib.h and primary Apple documentation. Changed the shared SystemSleepAssertions backend to kIOPMAssertPreventUserIdleDisplaySleep: it prevents idle display sleep and consequently idle system sleep. This supersedes the earlier display-may-sleep implementation default. Timers, renewal, stop/expiry, remembered mode and per-process ownership stay on the same service. No new option or additional assertion is needed.
- Updated General guidance, README, requirements, architecture, Stage 6b, manual checklist and AGENTS. Explicit Sleep/lid/low-power handling remains under macOS. No simulated input, external caffeinate process, privacy access or system sleep-timer changes.
- **51 core tests passed**, including fake-backend acquire/renew/release, expiry, failure and restore checks; warm search p95 **20.03 ms**. Isolated/canonical release builds and strict ad-hoc signature checks passed. The canonical app was normally quit before replacement and reopened through the desktop tool.
- The owner's already-active caffeine session restored after relaunch. General visibly showed Keep Mac awake checked, Awake until stopped and the revised screen-and-Mac guidance. Read-only pmset then showed a live Uficast-owned **PreventUserIdleDisplaySleep** assertion and global PreventUserIdleDisplaySleep = 1. No extra manual power toggle was performed. This verifies actual native assertion creation/restoration, not a controlled long idle, battery/lid or stop/expiry session.

### Caffeine follow-up observation

- On the owner's request to continue, performed read-only checks without changing app/system state. pmset showed the same Uficast-owned PreventUserIdleDisplaySleep assertion active for **19 minutes 31 seconds** at 20:49:58 (America/Los_Angeles). The corrected native assertion was still present.
- Read the power-management log for actual Display is turned on/off and Entering Sleep events. The latest recorded display-off event was **20:06:01**, followed by display-on at **20:11:17**, both before the corrected app's approximately 20:30 launch. No later display-off or system-sleep event appeared in the retrieved log.
- The current AC profile already had displaysleep=0 and sleep=0; these settings were only read. Recent user activity was also present, so this is continued-running/log evidence, not a controlled idle-prevention acceptance test. IODisplayWrangler did not expose matching power-state properties on this Mac; no success is claimed for that optional query.
- No new code change, rebuild, restart, power toggle or test rerun was needed. The corrected implementation remains checkpoint 8d18892. The remaining exact next step below is unchanged.

The caffeine idle check from this section is still open; it is carried into the next step of Stage 6m below.

## Stage 6m — launcher shortcut, focus display and clock contrast

- Owner requests (November 19, 2026): make Cmd+Space configurable, open the launcher on the display that has focus, and keep the menu bar clock readable on an inactive display. macOS dims the whole menu bar there; no public setting turns that off. The owner chose an experiment (option B): draw the clock as one explicit-contrast image. The owner approved the design `docs/superpowers/specs/2026-11-19-launcher-hotkey-display-clock-design.md` (commit c4334cb).
- Launcher shortcut: optional `launcherHotkey` in schema 1 (absent = Cmd+Space, default not written). Validation reserves the effective launcher shortcut against enabled app hotkeys in both directions. HotkeyService registers the configured combination; status text names it. General → Launcher has the native recorder (Escape cancels; Delete or Reset restores Cmd+Space). AppController validates and probes a candidate with register/unregister before saving; an unavailable combination is reported and not saved.
- Display: `show()` reads owner PID, layer, alpha and bounds of the frontmost app's front layer-0 window from the system window list (no Screen Recording/Accessibility), and `DisplayPlacement` chooses the screen with the largest overlap; fallback is the pointer's screen, then `NSScreen.main`.
- Clock: the button title is empty; text, power symbol and calendar are drawn into one non-template image, recolored black (aqua) or white (dark aqua) at draw time. Accessibility label/description and tooltip carry the clock text. `--preview-status-clock <png>` renders a fixed-text light/dark comparison.
- Separate earlier commits today: bc3117d lets `scripts/build.sh` read an optional git-ignored `local/build.env` (the owner's local output path is there, not in Git).

**Toolchain note (unresolved).** After the machine's update, `scripts/build.sh` fails with the default MacOSX27.0 SDK: Command Line Tools have no `SwiftUIMacros` plugin, so SwiftUI `@State` does not expand. `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` builds successfully. `scripts/test.sh` also fails under the new default `swiftbuild` system (TestingMacros is not passed to the compiler); `scripts/test.sh --build-system native` works, with a deprecation warning. The scripts are unchanged; adapting them needs the owner's decision.

Checks actually performed (all with `SDKROOT=…MacOSX26.5.sdk`):

- `scripts/test.sh --build-system native`: **57 core tests passed** (6 new: legacy decode keeps Cmd+Space and writes no field, custom round trip and validation, conflicts both ways including relabeled and disabled bindings, Quartz→Cocoa conversion, overlap choice, pointer fallback). Warm search p95 **18.02 ms** over 2,000 synthetic apps. The new tests were first seen failing to compile before the implementation existed.
- Isolated release build (`UFICAST_OUTPUT_ROOT=.build/check`) and strict signature verification passed. After a full rebuild only the pre-existing `AppController.swift:99` capture warning and linker search-path warnings remain.
- Native checks on that bundle passed: `--verify-menu-clock` (now also: non-template image, empty title, text inside the image, full-contrast ink brightness in aqua and dark aqua; tick phases 5, 7, 6 ms on the final build), `--verify-shortcut-recorder`, `--verify-keyboard-shortcuts`, `--verify-alias-editor`, `--verify-script-feedback`, `--verify-native-icons`.
- Offscreen previews inspected: status clock light/dark (black on light, white on dark, zzz/cup, calendar and text aligned) and General in light, which shows the new Launcher Shortcut row. The Reset button (shown only with a custom shortcut) was not rendered.
- Not performed: pressing a real recorded shortcut, relaunch persistence, the availability probe against a real conflict, placement on two displays, the clock on an actual inactive display, and the open-menu highlight look. The owner's running copy in the local output folder was not replaced; it requires a normal Quit first.

Owner-installed build and result (November 19, 2026):

- The owner quit Uficast normally; the build was then rebuilt into the owner's local output folder with `SDKROOT=…MacOSX26.5.sdk scripts/build.sh`, the strict signature check passed and the app was reopened.
- **Owner confirmed: the clock is readable on an inactive display.** The clock-contrast change is kept. Light/dark bar variants and the open-menu highlight were not reported separately.

## Stage 6n — AI text rewrite and translation (branch `feat/ai-text`)

- Owner request (November 19, 2026): rewrite English into correct, simple English and translate EN↔RU by keyboard, using `claude -p` with Haiku 5.5 or another CLI the owner configures.
  - The result is shown first; Enter inserts it where possible, otherwise copies it; Esc cancels.
  - Clipboard and macOS Services entry points; inline formatting kept.
  - Approved design `docs/superpowers/specs/2026-11-19-ai-text-rewrite-translate-design.md`; plan `docs/superpowers/plans/2026-11-19-ai-text-rewrite-translate.md`.
- Spike (owner-approved, two Haiku calls through `/bin/zsh -lc`): 5.14 s with the base flags and 2.78 s adding `--setting-sources project,local`. In both, stdout held only the answer and the markers were kept. No sample text reached files under `~/.claude`. The second variant is the default command.
- Implementation by task:
  1. Native worker stdin with no SIGPIPE.
  2. `AITextRunner`, `AITextPrompt`, `AITextPreferences` and `Configuration.aiText`.
  3. `SpanMarkup`.
  4. `RichTextBridge` and a separate `AITextPanelController` with the launcher's look.
  5. `AITextCoordinator`, Services in Info.plist and a nested event loop for Services.
  6. Carbon IDs 1000/1001 for clipboard shortcuts, the General → AI Text section and `NSApp.servicesProvider`.
- Builder rulings (details in the design and ARCHITECTURE):
  - Separate result panel.
  - The shown copy drops source text colors.
  - A second Service request during a wait returns an error.
  - The timeout note is kept through a retry.
  - Dev-only `--preview-settings … --height N`.

Checks actually performed (all with `SDKROOT=…MacOSX26.5.sdk`):

- `scripts/test.sh --build-system native`: **78 core tests passed**. New tests cover:
  - stdin: large input, early exit, timeout and exact bytes.
  - Runner: trimmed output, missing CLI with stderr, empty output, cancel and no shell injection.
  - Configuration: legacy defaults, command limits, conflicts and round trip.
  - Prompt and clean.
  - Markers: escaping, round trip, moved markers, broken markers and entities.
  - Each new test was first seen failing (missing API).
- Release build into `.build/check` with strict signature check. No new warnings; only the pre-existing `AppController` capture warning, now at line 109.
- `--verify-ai-text` passed:
  - Rich round trip with bold and link, and pasteboard types.
  - Panel hints and Enter/Esc behavior.
  - With a fake runner: empty and image clipboard, clipboard rewrite, Esc during work with a late result, failure then retry, Service replacement keeping bold, Service cancel, Service deadline then copy mode, broken-marker fallback.
- All other native checks still pass.
- Settings preview (light) visually inspected: the AI Text section with command, Apply/Reset, recorders and captions.
- Not performed:
  - Any real Service invocation from another app, or pbs/System Settings registration of the Services.
  - Replacement and formatting in Mail/Notes/Safari.
  - The clipboard flow with a real `claude` call through the app, and real global shortcut delivery.
  - Dark appearance of the panel, and a Codex command (Codex is not installed).
- The owner's running copy was not replaced.

Final whole-branch review: a fresh reviewer on Opus (Fable was unavailable to this account) found no critical issues. Five problems were fixed, each with a native check that failed first:
1. A Service delivered from a main-queue block never received its result. Results now return through `RunLoop.main.perform` from a detached task.
2. An image-only selection (U+FFFC) counted as text.
3. An answer that is empty after cleaning was offered as a result, so Enter would have deleted the selection.
4. HTML without a charset garbled Cyrillic; it is now decoded as UTF-8.
5. The pre-existing `InstanceLock` test was flaky: concurrent spawns briefly hold the descriptor, and the test now waits up to 1 s.

After the fixes the suite passed 6 runs in a row (78 tests), and all 7 native checks pass. Deferred minors:
- A rare cancel-ordering race can leave a new request on "Working…" until Esc.
- The default command is written to the config.
- The message for an app/AI hotkey conflict mentions only the launcher.

Owner check (November 19, 2026): the build from `feat/ai-text` (891df35) was installed after a normal Quit and `pbs -update`. **The owner reported that AI text works** and asked to merge. Which individual checklist items were tried was not reported; items not named stay open in `docs/MANUAL_TESTS.md`. Merged into main afterwards.

**Exact next step:** the owner tries the Calculator checklist in `docs/MANUAL_TESTS.md`. Then the items below.

**Earlier next step (still open):** remaining AI text checklist items the owner has not named (formatting in Mail/Notes, Service timeout, Codex), the Launcher shortcut and two-display placement checks; decide whether `build.sh`/`test.sh` should adapt to the new toolchain; the caffeine idle check and other daily-use gaps remain open. Then the owner installs the build (quit Uficast first) and runs the AI text items in `docs/MANUAL_TESTS.md`; Services may need logging out and in or `/System/Library/CoreServices/pbs -update` before they appear. Also still open: the Launcher shortcut and two-display placement checks; decide whether `build.sh`/`test.sh` should adapt to the new toolchain. The caffeine idle check (screen stays on while active; stop/expiry restores idle behavior) and other daily-use gaps remain open.


## Stage 6o — Calculator

- Owner request (November 19, 2026): calculate in the launcher search; Enter copies the result; remember calculations and show them as suggestions below when a formula is started or `calc` is typed; restore an unfinished formula when the launcher reopens. The owner declined further questions, so scope and defaults below are the builder's calls (see REQUIREMENTS "Calculator").
- Builder calls:
  - A custom evaluator with `+ - * / ^ %`, `× ÷ −`, parentheses and `.`/`,` decimals. No functions, units or currencies.
  - Result copied with a dot decimal and at most 15 significant digits.
  - `1,000` is refused as ambiguous instead of read as 1.
  - History is the last 50 distinct calculations, kept in UserDefaults `calculator.v1`, outside the exported config.
  - Enter on a history row copies its result; Tab moves its expression into the field.
  - Enter closes the launcher and returns focus to the previous app so Cmd+V works at once.
  - The restored draft is selected, so typing replaces it. This is the single exception to the clear-on-hide rule; errors and script input are still cleared.
  - `calc` keeps the Calculator app first, with history below it.
- Implementation: `Calculator`, `CalculatorQuery` and `CalculatorState` in `Sources/UficastCore/Calculator.swift`; `LauncherEntry.Kind` gains `.calculator` and `.history`; `LauncherPanelController` composes rows in `searchResults(for:)`; AppController loads/saves the state.
- Checks actually performed (with `SDKROOT=…MacOSX26.5.sdk`):
  - `scripts/test.sh --build-system native`: **93 core tests passed** (15 new, each first seen failing to compile before the API existed). Warm search p95 **17.75 ms**.
  - `--verify-calculator` (written before the controller code and first seen failing to compile) passes: live row, bare number stays an app search, `calc` ordering, Tab edit, Enter on live and history rows, history bump, draft save/restore/selection/clear, state-change reporting, and the real clipboard's change count unchanged.
  - Isolated and canonical release builds and strict signature checks pass. The other seven native checks still pass on the isolated build.
  - Light and dark launcher previews (`--preview-launcher … --calculation`, public fixtures) were inspected.
- Integration: the owner asked for the calculator in main before any upstream pull request; `feat/calculator` was fast-forward merged into main (no divergence) and pushed to the fork, then a main-to-main pull request was opened against the original repository.
- Installed: the running app was quit normally, rebuilt into the owner's local output folder and reopened.
- Not performed: typing in the real launcher, paste into another app, relaunch persistence with a real draft, and anything with the owner's real history. Items are in `docs/MANUAL_TESTS.md` under Calculator.

## Stage 6p — Persistent frequency ordering

- Owner request (November 20, 2026): sort launcher applications by frequency of use. The ranking already used counts inside a session (empty search and ties), but `launcher.usage` was in memory only, so every restart returned to alphabetical order.
- Builder calls: keep the match tiers (an exact alias must still win) and only persist and widen what counts. Counts live in UserDefaults `usage.v1` through the new `UsageStore` (identifiers, counts and dates only; 1,000 most recent entries; corrupt or non-positive data is ignored). `LauncherPanelController.recordUse` is the single counting point, now also used when an app hotkey activates a running app. Hiding an app does not count. No time decay.
- Checks actually performed (with `SDKROOT=…MacOSX26.5.sdk`): `scripts/test.sh --build-system native` **99 core tests passed** (6 new, first seen failing to compile). `--verify-usage-order` (written first, seen failing to compile) passes: alphabetical without history, reordering after recorded uses, a save report per use, and the same order in a second controller loaded from the encoded data. `--verify-calculator` still passes.
- Not performed: relaunching the real app and observing the order, and the app-hotkey counting. Items are in `docs/MANUAL_TESTS.md` under Frequency ordering.
- Integration: `feat/usage-ranking` was fast-forward merged into local main at the owner's request and the branch was deleted. Not pushed yet.
- Also this session: the merged `feat/calculator` branch was deleted locally and in the fork, and `AGENTS.md` (which `CLAUDE.md` links to) gained the rule to quit and relaunch the app after every build.

## Stage 6q — Shortcuts instead of Services

- Owner request (November 20, 2026): remove the macOS Services (useless) and ask for a Shortcut that takes the selected text, else the clipboard, and a Settings button to create it. The owner chose to try it as built and redo it if it does not work.
- Research before building (sources in the chat): a Shortcut that is a Quick Action with "If there's no input: Get Clipboard" gives exactly selected-text-else-clipboard, but the selection reaches it through the Services mechanism, so apps that do not offer Services (many Electron apps) fall back to the clipboard. Apple's documentation does not confirm that the shortcut's own keyboard shortcut passes the selection. `shortcuts sign` was run on a minimal file and failed even in local mode without an iCloud sign-in, so signing cannot be relied on. App Intents were rejected: SwiftPM does not produce `Metadata.appintents` and the workaround needs Xcode's `appintentsmetadataprocessor`.
- Builder calls:
  - A `uficast://rewrite|translate?text=…` link is the hand-off (plain text, one way). Enter copies; replacement of the selection and formatting for linked text are gone.
  - Any app or page can open such a link, so a link only starts a request: no copy until Enter, 20,000-character limit, a link without text uses the clipboard.
  - The Services machinery (nested event loop, replace mode, `NSServices`, `servicesProvider`) was deleted rather than kept dormant.
  - First try: a generated `.shortcut` file with URL Encode, URL and Open URLs actions. It failed on the owner's Mac; see "Redo" below.
- Checks actually performed (with `SDKROOT=…MacOSX26.5.sdk`):
  - `scripts/test.sh --build-system native`: **107 core tests passed** (8 new for link parsing and the shortcut plist structure and UUID chain, first seen failing to compile). Warm search p95 **18.23 ms**.
  - `--verify-ai-text` was rewritten first (it failed to compile) and passes: panel hints (Copy only), clipboard rewrite, Esc during work, failure and retry, link text instead of clipboard, link without text, overlong and unknown links refused, rich clipboard keeping bold, broken-marker fallback. All other native checks pass on the isolated release build, whose Info.plist has the `uficast` scheme and no `NSServices`.
  - The General settings preview (light) was inspected: the AI Text section shows the two Create buttons and the explanation.
- Owner result (November 20, 2026): Create Shortcut opened Shortcuts, which answered **"Importing unsigned shortcut files is not supported. Please use another sharing option."** The file route is closed on this Mac (`shortcuts sign` also needs an iCloud sign-in).
- Redo (same day): `ShortcutFile` and its tests were deleted. New `ShortcutGuide` (UficastCore) holds the name, five steps and a one-line Run Shell Script script. The buttons now copy that script, open `shortcuts://create-shortcut` and make General → AI Text show the steps (`SettingsModel.shortcutGuide`).
  - 3 core tests run the script in zsh with a stub `open` and read the recorded link back through `AITextURL`, including quotes, `$`, backticks, `&`, `+`, `%`, Cyrillic, newlines and empty input.
  - 107 core tests pass in total. The General preview with the steps (`--preview-settings … --general --ai-guide`) was inspected. The `uficast` scheme is registered with Launch Services (read-only `lsregister -dump`).
- Not performed: building the shortcut by hand, the real wording of Shortcuts' controls versus the steps, the selection input in real apps, the shortcut's own keyboard shortcut, and real link delivery by `open "uficast://…"` (it would start a real AI request). Items are in `docs/MANUAL_TESTS.md` under AI text.
- Owner report (November 20, 2026): the hand-built shortcut works when run by hand, but its keyboard shortcut (Ctrl+Cmd+R, shortcut "Rewrite") does nothing. Root cause not found yet.
  - Established: the script, the link and the panel work (manual run). Uficast's own hotkeys do not include Ctrl+Cmd+R (only Translate-from-clipboard is Ctrl+Cmd+T); no system symbolic hotkey uses it.
  - Dead ends: the unified log is not readable here (`Operation not permitted`, `log stream` needs admin). An early "no log lines" result was invalid because zsh's builtin `log` ran instead of `/usr/bin/log`.
  - Hypotheses at the time: (1) the hotkey is a Services key equivalent, which does nothing without a selection or in apps without Services; (2) Shortcuts only fires hotkeys while the Shortcuts app runs; (3) a conflict with another app; (4) the result panel is closed at once by a focus change when the shortcut finishes.
  - **Resolved:** the owner changed the combination to Cmd+Ctrl+Shift+R and everything worked. Because nothing else changed, hypotheses 1, 2 and 4 do not explain it; Ctrl+Cmd+R was most likely taken by another app. Which app was not identified. The guide's last step now recommends a ⌃⌘⇧ combination and says why. The diagnostics stay: they are cheap and text-free.
  - Diagnostics added so the next test discriminates: Recent Runs now records "<Action> link received (N characters)." when a link arrives and "The result panel closed because it lost focus." when the panel closes that way. No link text is recorded. `--verify-ai-text` covers both and the absence of a false report after Enter.
- The deploy order rule in `AGENTS.md` changed the same day: build to a staging folder, quit the old app, copy the build over the owner's bundle, open the new app.
- The hotkey-delivery check in `AITextVerification.swift` (`hotkeyDelivery`, written by another session) was in the working tree throughout; it passes inside `--verify-ai-text` and was committed on November 20, 2026 at the owner's request. It sends the Carbon hotkey events to the application target, so no key is typed and no privacy grant is involved.

## Stage 6r — Compact settings

- Owner request (November 20, 2026): make the settings page compact and good-looking instead of a long scroll, with almost every element on one row. The owner approved option A of two: a single page of two-column cards (option B, a sidebar of sub-pages, was declined). The owner also sent a screenshot of how Shortcuts opens a new shortcut ("Title" at the top left, ⓘ and an action library on the right), which matches the steps; they now say "Click “Title”", "Click ⓘ" and "Search Actions for Run Shell Script".
- Built: `SettingsCard` and `InfoButton` (`SettingsCards.swift`); a two-column General (Launcher, Menu Bar Clock, Power & Keyboard | AI Text, Application Folders, Configuration) in `ViewThatFits`, with a `ScrollView` fallback for tiny windows; a slim capsule top bar; a footer with a truncated status and a Recent Runs popover; the shortcut steps in a sheet. Window default 980×640, minimum 820×540. Long captions moved behind ⓘ; status lines stay as one or two caption lines. The footer padding that clipped the status text in the owner's screenshot is now a plain 16 pt.
- Unchanged: every control's behavior, bindings and accessibility labels; the Commands page (only its top bar changed).
- Checks actually performed (with `SDKROOT=…MacOSX26.5.sdk`):
  - **107 core tests passed**; warm search p95 **18.07 ms**. The guide's steps tests still pass with the new wording.
  - All nine native checks pass on the release build in the staging folder, including the ones that host the Settings view (recorder, alias editor, keyboard shortcuts).
  - Offscreen General previews in light and dark at the default size show everything without scrolling; a 420-point-high window falls back to scrolling. The guide sheet and the regenerated Commands screenshot (`docs/screenshots/commands.png`) were inspected. The other three README screenshots were not touched.
- Not performed: using the new page by hand (popovers, every button, the sheet over the real window), a check at minimum window size on a real display, and the Recent Runs popover with real runs. Items are in `docs/MANUAL_TESTS.md` under Compact settings.
- Deploy followed the new order: build into `.build/staging`, normal quit of the old app, copy over the owner's bundle, open.

### AI result panel text size

The owner found the translation in the AI result panel too small: results without a source font were drawn as 12 pt Helvetica. At the owner's request the shown copy now uses the font of the owner's iTerm profile (Meslo LG S NF Mono, 16 pt, vertical spacing 1.0, so the natural line height), with the system monospaced font as the fallback when Meslo is not installed. Source fonts only contribute bold/italic; source paragraph styles are dropped for display. The copied result is unchanged. Failure/working text uses the same font, and the panel grew from 720×340 to 760×420. `--verify-ai-text` passes. The build needed `SDKROOT=…/MacOSX26.5.sdk` (the unresolved toolchain note above). The panel itself is not previewed offscreen, so the owner's look at a real translation is pending. The new build is installed and running.

### Translate returned English unchanged

The owner saw Translate return the English source as English. Cause: the prompt said "if it is mainly Russian, translate into English; otherwise into Russian", and Claude Haiku 5.5 sometimes ignored the condition, most often for formatted (style-marker) text copied from a browser. A neutral reproduction returned English in 1 of 3 marker runs and 0 of 3 plain runs. The direction is now decided in code (`AITextPrompt.isMainlyRussian`: Cyrillic letters outnumber Latin ones, markers ignored) and named in the prompt ("from English into Russian. The result must be written in Russian."). A neutral reproduction with the new prompt translated in 9 of 9 parallel runs. 108 core tests (one new) and `--verify-ai-text` pass; the build used the `SDKROOT` workaround. Real use of Translate from the owner's shortcut is pending.

### Earlier cursor report checkpoint

Commit 62e8296 preserved an unrelated stationary-cursor report. Its source/disappearance was not established; no app code changed for that report. Do not treat it as a verified Uficast defect or interact with unrelated apps to investigate it without a new request.

## Stage 6s: GitHub pull requests

- Owner request (November 20, 2026): reach one of the owner's open pull requests from the launcher: `gh` -> Tab -> type to filter -> Enter opens it in the browser. Approved design `docs/superpowers/specs/2026-11-20-github-pull-requests-design.md` (the owner changed two things: `gh` is found on `PATH`, and a missing `gh` only shows an install message; the 5-minute cache lifetime was added at the owner's request). Requirements: REQUIREMENTS "GitHub pull requests"; architecture: ARCHITECTURE "GitHub pull requests (Stage 6s)".
- Built (Tasks 1-6 and one fix wave after the final whole-branch review, all on main):
  - `PullRequest`, `PullRequestParser` and `PullRequestFilter` in `Sources/UficastCore/PullRequest.swift`.
  - `GitHubPullRequestLoader` and `GitHubCLI` (finds `gh` on `PATH` plus the standard directories).
  - `PullRequestStore`: shares one load, caches success for 5 minutes, `invalidate()`, `cancel()`.
  - `BuiltInCommand.pullRequests` (alias `gh`).
  - The pull-request mode in `LauncherPanelController` and the routing in `AppController`.
- Builder calls: pull-request mode is its own mode that reuses the token, field and table; Enter on the entry behaves like Tab; a late success is cached and a late failure is dropped; only the command's usage counter is recorded (no pull request data on disk); drafts included and labelled; 100 newest open pull requests; no refresh control.
- Final-review rulings: the `gh` command matches its alias only exactly (`LauncherEntry.matchesAliasByPrefix` is false for it), so typing `g` alone no longer ranks the command by alias (it can still match by its name, ordered by use frequency) while `cafe`/`decafe` keep prefix matching; `enterPullRequests` returns nil when the panel is hidden or the mode is already on; a catalog refresh no longer replaces the mode's empty text.

- Owner feedback after the first real look (November 20, 2026): pull request rows no longer show "Pull Request" on the right; the title uses the full row width and `owner/repo #number` (plus ` · Draft`) is a subtitle below it. Ordinary rows are unchanged. `--verify-pull-requests` gained a "row layout" check (kind hidden, title reaches the right edge, subtitle under the title, ordinary row unchanged); it was seen failing first and then passing. The on-screen look of the new row has not been inspected (no screenshot).

Checks actually performed (with `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`, the unresolved toolchain note above):

- `scripts/test.sh --build-system native`: **136 core tests passed** (exit 0). New tests cover the pull-request model, parser and filter, the loader (with a fake `gh` script), the store (with a fake clock), the built-in command and the exact-alias ranking of `gh`.
- A staging build (`UFICAST_OUTPUT_ROOT=.build/staging`) succeeded, and the native checks `--verify-pull-requests`, `--verify-calculator`, `--verify-usage-order`, `--verify-script-feedback` and `--verify-native-icons` each exited 0 with their PASS line (exit codes read directly).
- Every task had a spec-compliance and quality review (all approved, no Critical or Important findings); the final whole-branch review and a scoped re-review of its fix wave were also run.

Not observed (pending, none of these is recorded as passed):

- A real `gh` run with real pull requests.
- The browser actually opening the selected pull request.
- The physical Tab/Enter/typing flow in the real launcher.
- The on-screen layout of the mode (no screenshot was taken).
- A signed-out `gh`; the not-installed message is covered by unit tests only.
- Cache expiry in real time (it is unit-tested with a fake clock only).
- AppController routing (no automated test).

Known gaps accepted after review (Minor, not fixed): store tests do not pin the slot-id guard or a loader that ignores cancellation; the Tab check in `--verify-pull-requests` would also pass without the Tab swallow; Cmd+F does not leave the mode; quitting cancels a running `gh` but does not wait for the child to stop; the cache age uses the wall clock; a timed-out `gh` shows no stderr; the parser drops rows with fractional-second dates; `LauncherPanelController.swift` grew to about 1,100 lines because the native check lives in the production file (existing pattern).

Documented limitations: at most the 100 newest open pull requests; `gh`'s default host only; `GH_HOST` set in a terminal profile is not visible to a GUI app; a `gh` that is only in a directory added by a terminal profile (for example `~/.local/bin`) counts as not installed; pull requests in SSO-restricted organizations may be missing without any error; no manual refresh control (the list is reloaded on the first entry after 5 minutes).

**Exact next step:** the owner quits Uficast normally, installs/uses the current build, and runs the items under "GitHub pull requests" in `docs/MANUAL_TESTS.md` (real `gh` with real pull requests, signed-out `gh`, first Tab latency, reload after 5 minutes, Keep Awake untouched, Esc/Backspace, light and dark layout). Record the results here. The earlier open items above stay open.
