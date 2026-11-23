# Project continuity

- Read `docs/plan/PROGRESS.md` first, then the requirements, architecture, and relevant stage in `docs/plan/IMPLEMENTATION_PLAN.md`.
- The owner approved Swift + AppKit and an English UI and plan. Preserve the distinction between confirmed requirements and implementation defaults.
- Implement the next unfinished stage as a reviewable increment. Do not silently expand the scope to other Raycast features.
- Keep documentation in English. Conversation with the owner may be in Russian.
- At each session boundary, update `PROGRESS.md` with actual changes, checks and results, unresolved issues, and the exact next step. Never mark an unperformed manual check as passed.
- Keep stages small enough to resume without chat history. Record architectural changes in `ARCHITECTURE.md` and adjust the remaining plan when evidence requires it.
- The owner explicitly requested committing the plan and work for continuity. Commit completed increments after appropriate verification; stage only relevant project files. Do not commit private configuration, real internal URLs, credentials, or build artifacts.
- Push to the fork's `main` (`git push origin main`) after each verified commit, so every good state is recoverable on the remote. If a change turns out wrong, go back to the earlier state with a new commit (`git revert`) or by restoring files from an earlier commit, then push that. Never force push or rewrite pushed history.
- After a change to the app, run the latest build in this order, so the owner always runs it:
  1. Build, into a staging folder (`UFICAST_OUTPUT_ROOT="$PWD/.build/staging" scripts/build.sh`), so the running bundle is untouched.
  2. Close the old app with a normal quit, not `kill`, because a normal quit saves the remembered caffeine state.
  3. Copy the staged bundle over the owner's bundle (the output path in `local/build.env`) and open the new app.

  Never overwrite the executable of a running app.
- Do not change the machine's hotkeys, keyboard mappings, login items, or privacy grants merely to verify code. Interactive setup must be clearly tied to an explicit user action in the app or an authorized manual test.

- Mandatory updated requirement: Uficast must not require or request Accessibility or Input Monitoring. The launcher uses RegisterEventHotKey with Cmd+Space (either Command key) by default; the owner can choose another combination in General. Do not restore the earlier side-specific event-tap design.

- Accepted additions: per-application show/hide hotkeys, built-in Keep Awake, singleton opening, real app icons, startup checkbox, and U.S./Russian wrong-layout search. Convert search queries only; never script arguments.

- App Hotkey cells record on double-click; Escape cancels without saving, and × clears an assigned shortcut. Built-in caffeine/cafe and decaffeine/decafe commands use the shared Keep Awake service; preserve user-alias precedence.

- Script folders are connected through Commands. Discovery reads metadata only and never executes or copies scripts; preserve existing customizations and unavailable roots. Keep private script contents/URLs and personal folder paths out of repository fixtures and screenshots.

- Alias cells/inspector edit on double-click; Enter saves, Escape discards, and × removes. Script execution keeps its current launcher view while running and offers failure text/Edit Input on failure. Never retry automatically or let a late result overwrite newer input/reopen a dismissed panel.

- Local Settings shortcuts: Cmd+, and owner-requested Cmd+P; Esc cancels an inline edit first, otherwise closes Settings. Remember caffeine mode/deadline locally across normal exits. Hiding the launcher clears its error/input and invalidates late completion; never show that stale error on reopen.

- Calendar work was developed on `codex/day0-calendar-experiment` and the owner authorized merging it into main. Uficast uses the clock as the single upper-menu-bar Uficast button. Match Day-O with native NSDatePicker, compact menus centered against the actual menu window, format/Show Icon settings and seconds aligned to system boundaries. Keep a zzz/cup state indicator left of the optional calendar within the same button. No Dock addition.

- Caffeine must keep the screen on as well as prevent idle system sleep. Use the shared native PreventUserIdleDisplaySleep assertion for launcher/menu/General sessions; the earlier system-only/display-may-sleep default is superseded. Preserve timed expiry, remembered state and release ownership.

- GitHub pull requests: the built-in `gh` command (Tab or Enter on it) opens a filterable list of the owner's open pull requests, loaded with the `gh` CLI found on PATH, kept in memory for 5 minutes, newest first; Enter opens the selected pull request in the browser. Exact argv with no shell, the filter never reaches `gh`, no pull request data is written to disk, and no new permissions are requested. A late result never changes the view or reopens the panel, and a failure is never cached or retried automatically.
