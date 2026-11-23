# GitHub pull requests command — design

Date: 2026-11-20. Status: approved by the owner on 2026-11-20 with two changes: `gh` is found on `PATH`, and a missing `gh` only shows an install message.

## Intent

The owner wants to reach one of their own open pull requests from the launcher without opening GitHub and navigating to it. The flow is: open the launcher, type `gh`, press Tab, see a list of the owner's open PRs (newest first), type a few letters to narrow the list by title, press Enter, and the PR opens in the default browser.

The list is fetched with the GitHub CLI (`gh`) that is already installed and signed in on the owner's Mac. Uficast does not talk to GitHub itself and stores no GitHub credentials.

The reference workflow for scripts is `k` → Tab → input → Enter → browser. This feature feels the same, except that the second step is a filterable list instead of a free-text argument.

## Goals

- `gh` + Tab (or Enter) in the launcher shows the owner's open PRs across all repositories, newest created first.
- Typing filters the list fuzzily by PR title; the order is decided inside Uficast, not by `gh`.
- Enter opens the selected PR in the default browser and closes the launcher.
- `gh` runs on first use. The list is then kept for 5 minutes and shown instantly; after that the next entry loads it again (cache invalidation, added at the owner's request after approval).
- Clear, non-sticky failure messages (`gh` missing, not signed in, timeout, bad output).
- No new privacy permission, no shell interpolation, no PR data on disk.

## Non-goals

- Other queries (review requested, closed, per repository, other authors), other GitHub hosts, GitHub Enterprise host selection.
- A refresh control or background refresh. A new PR appears the first time the command is opened after the 5-minute lifetime of the kept list has passed. (A manual refresh is easy to add later; not part of this increment.)
- Checkout, review, merge or any action other than opening the PR.
- A general "script prints a list" mode (see Approaches, option B).
- Settings UI for this command. Persisted cache. Notifications.
- Raycast compatibility.

## Anti-goals (failure even if it technically works)

- Asking for Accessibility, Input Monitoring or any new grant.
- Running `gh` through a shell string, or letting launcher text become part of a command line. The filter text never reaches `gh`.
- Writing PR titles, URLs or repository names to disk, logs, the exported configuration or test fixtures.
- A late `gh` result replacing newer input, reopening a dismissed panel, or showing a stale error after the launcher was hidden and reopened.
- Automatic retries.
- Changing existing behavior of `caffeine`/`decaffeine`, scripts, calculator, alias precedence, or Enter on any other entry.

## Constraints from the project

- Swift + AppKit, English UI, no external packages. Existing patterns: `BuiltInCommand` (built-ins, user alias wins over built-in alias), `NativeRun` (exact-argv process worker with timeout, output caps and cancellation), `AITextRunner` (an external CLI used from a GUI app), `LauncherPanelController` (search mode and argument mode), `SearchIndex` and `KeyboardLayoutSearch` (fuzzy search and U.S./Russian wrong-layout variants for queries).
- A GUI app does not inherit the terminal `PATH`. `ScriptRunner` already uses `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`.
- Hiding the launcher clears transient input and errors and invalidates late completion.
- Repository fixtures and screenshots must not contain real PR data, internal URLs, organization or repository names. Use fake `org/repo` data.
- A manual check that was not performed is never recorded as passed.

## Behavior

### Entry point

- A built-in command named **GitHub Pull Requests** with default alias `gh`. It is found like other built-ins; an explicit user alias `gh` takes precedence, as for `cafe`/`decafe`.
- Tab on it enters pull-request mode. Enter does the same (consistent with "Enter on a command that needs input enters input mode, like Tab"). Neither runs anything else.

### Pull-request mode

```
┌──────────────────────────────────────────────────┐
│ [gh]  flaky                                      │
├──────────────────────────────────────────────────┤
│ ▸ Fix flaky retry in upload       org/api   #412 │
│   Flaky cache test, quarantine    org/web   #398 │
└──────────────────────────────────────────────────┘
  ↑↓ Select  ·  ↩ Open  ·  Esc Back
```

- The command token stays at the left, the single-line filter field beside it, results below. Same look as argument mode.
- Escape returns to the normal search with the previous query. Escape in normal search closes the panel. Backspace in an empty filter returns to search (same as argument mode).
- Up/Down move the selection. The first row is selected after every filter change, and only when there is a row; with no rows (loading, empty, failure, no match) nothing is selected and Enter does nothing.
- Pull-request mode is its own mode, not an extension of argument mode. It reuses the token button and the single-line search field and the results table, and does not use the multi-line argument text view. It follows the same Escape/Backspace conventions and the same rule that hiding the launcher leaves the mode and clears the filter.
- Entering the mode from the built-in entry (Tab or Enter) never opens anything. Enter inside the mode opens the selected row.
- While loading, typing still edits the filter (applied when the list arrives), Enter does nothing, and Escape leaves the mode without cancelling the load.

### Loading and failure

- First entry in an app run starts one `gh` load. The results area shows "Loading pull requests…". If the owner leaves and re-enters while it runs, the same load is shared; it never starts twice.
- Success: the list is kept in memory for 5 minutes, counted from the moment the load finished. Re-entering within that time shows it at once with no process started. An older list is treated as absent: the next entry shows the loading state and loads again. The store also offers an explicit invalidate that drops the list at once (nothing calls it yet; it exists for a future refresh control and for tests).
- Failure: nothing is cached. The message appears in the lower area (reason plus the first 512 characters of stderr, as for script failures; stdout only if stderr is empty). The hint reads "Esc Back". Leaving and entering again is the explicit retry. There is no automatic retry.
- Empty list: "You have no open pull requests." (cached like any success).
- Missing executable: the lower area shows "GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login." Nothing else is offered or attempted; Uficast never installs anything. Like any failure, it is not cached.
- A result that arrives after the owner left pull-request mode or hid the launcher fills the in-memory list only. It never changes the visible view, never reopens the panel, and never shows an error. A late success is cached, so the next entry shows the list at once. A late failure is dropped silently and nothing is cached, so the next entry starts a fresh load.
- Leaving the mode does not cancel the load; the 30 s timeout keeps running. Quitting Uficast cancels a running load, the same way it cancels running scripts.

### Ordering and filter

- Empty filter: newest `createdAt` first.
- Non-empty filter: fuzzy match on the title, best score first, ties newest first. The query goes through the same normalization and U.S./Russian wrong-layout variants as launcher search (this is a search query; it is never passed to `gh`).
- Each row shows the title over the full row width and, as a dim subtitle on a second line, `owner/repo #number` (drafts add ` · Draft`). The kind label ("Pull Request") that other rows show on the right is not shown on these rows. No icons are fetched; a fixed SF Symbol is used. (Layout changed at the owner's request on November 20, 2026, after the first real look.)

### Open

- Enter opens the selected row's URL with `NSWorkspace.open`. The URL must be an absolute `http` or `https` URL with a host (same rule as script URL results); rows whose URL fails this are dropped when the output is parsed.
- On success the launcher closes without restoring focus to the previous app (the browser comes forward) and the use of the command is recorded for frequency ordering. Only the built-in entry's own usage counter is written (same key and storage as every other entry); individual pull requests are never recorded or ranked, so no PR data reaches disk. On failure the panel stays open and shows "Could not open the pull request."

## Data source

- Command (exact argv, no shell):
  `gh search prs --author @me --state open --sort created --order desc --limit 100 --json number,title,url,repository,createdAt,isDraft`
- `--sort created --limit 100` makes `gh` return the 100 newest PRs rather than the best matches. Uficast still sorts by itself and does not rely on the order of the output. More than 100 open PRs is a documented limitation: the oldest ones are not listed.
- Executable: `gh` is looked up on `PATH` (owner's decision), not at a fixed path. The search list is the directories of the app's own `PATH`, followed by the standard ones `ScriptRunner` already uses (`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`), without duplicates. The first directory that holds an executable file named `gh` wins; if none does, the "not installed" message is shown. The child process gets that same `PATH`. No shell is started to resolve it. Limitation: a GUI app does not see directories that only a terminal profile adds (for example `~/.local/bin` or a version manager), so `gh` installed only there counts as not installed. Environment: the app's environment, that `PATH`, plus `GH_PROMPT_DISABLED=1`, `NO_COLOR=1`, `GH_NO_UPDATE_NOTIFIER=1`. Timeout 30 s. Working directory: a private empty or temporary folder.
- `gh search prs` uses GitHub's search API, so it has search rate limits, and PRs in organizations that require SSO authorization of the `gh` token may be missing from the result without any error. This is a documented limitation, not handled. On the owner's Mac `gh` is at `/opt/homebrew/bin/gh` and a real `gh search prs --author @me` call already returned the owner's PRs from the terminal, so the manual check can expect it to work.
- Host: `gh`'s default host only. A `GH_HOST` set in a terminal profile is not visible to a GUI app; this is a known limitation, not handled.
- Output parsing: strict JSON decode of an array. Invalid JSON, or output longer than the process output cap, is the error "Unexpected output from gh." Fields used: `number`, `title`, `url`, `repository.nameWithOwner`, `createdAt` (ISO 8601), `isDraft`. Rows with an empty title or invalid URL are dropped.

## Approaches considered

| | A. Built-in `gh` command (chosen) | B. Generic "script prints a list" mode |
| --- | --- | --- |
| What | Swift code in Uficast runs `gh`, parses JSON, shows the list. | A script declares list output (`title<TAB>url`); Uficast shows and filters it; the owner writes `gh-prs.sh`. |
| For | Smallest verifiable step; no private data in the repository; matches how `caffeine` is built in. | Reusable for logs, tickets and so on. The script stays with the owner. |
| Against | A list from a command exists only for `gh`; another source needs new code. | New metadata, output format and validation of external lines; bigger scope than the owner asked for. |

The owner chose A. The list mode in the panel is built around a plain list of rows, so B could be added later without redoing the UI. Not building B now.

(An earlier reading of the request as a zsh completion was dropped: the owner meant the launcher.)

## Architecture sketch

- **UficastCore**: a `PullRequest` value type; a loader protocol with a `gh`-backed implementation built on `NativeRun`; a pure function that parses output and a pure function that sorts and filters; a small in-memory holder that shares one in-flight load and caches only success. `BuiltInCommand` gains the new command without changing `caffeine`/`decaffeine`. `LauncherEntry.Kind` may gain a row kind for pull requests.
- **Uficast (app)**: `LauncherPanelController` gets a pull-request mode next to argument mode (token, filter field, rows, loading/failure area, load-generation id so late results are ignored). `AppController` owns the loader, routes Enter/Tab on the built-in to the mode, and opens URLs.
- No change to configuration schema, persistence or permissions.

## Verification plan

- Core unit tests with a fake loader and fake data: output parsing (valid, invalid JSON, dropped rows, drafts), URL validation, sorting and filtering (empty filter, fuzzy, ties, wrong-layout query), error mapping (missing `gh`, non-zero exit, timeout, oversized output), cache behavior (success cached, failure not, concurrent entries share one load).
- A native `--verify-pull-requests` check in the style of `--verify-ai-text`, with a fake loader and fake opener: Tab enters the mode, filtering changes rows, Enter opens the expected URL once, Escape returns to search, a late result after hiding does not reopen or change the view, existing built-ins still behave.
- Existing test suite and native checks still pass.
- Manual, owner-led and not claimed until done: a real `gh` run with real PRs, an error case such as signed-out `gh`, and the browser opening.

## Documentation

`REQUIREMENTS.md` (owner addition, 2026-11-20), `ARCHITECTURE.md` (new section), `PROGRESS.md` (new stage with actual results and the exact next step), and a README line. All in English, with fake examples only.

## Decisions

**Owner decided:** the launcher flow (`gh`, Tab, type, Enter); a built-in command rather than a script; open in the browser; load on first use; Uficast sorts.

**Defaults chosen by the assistant** (proposals the owner can change): alias `gh` and Enter behaving like Tab; only open PRs authored by the owner, across all repositories; newest by creation date; 100 PRs maximum; list kept for 5 minutes then invalidated (the owner asked for invalidation; the length is my call), no refresh control; drafts included and labelled; filter on the title only, with wrong-layout variants; `gh` looked up on the app's `PATH` plus the standard `ScriptRunner` directories (the owner chose `PATH` over fixed paths; the exact search list is my call); 30 s timeout; the error texts above; pull-request mode as its own mode that reuses the token, field and table; loading-state interactions (typing edits the filter, Enter does nothing, Escape leaves without cancelling); late success cached and late failure dropped; only the command's usage counter recorded; the SSO and rate-limit limitation documented rather than handled.

**Left to the builder:** type and file names, exact row and token layout, output size cap, test names, whether `fuzzyScore` is shared with `SearchIndex` or reimplemented.
