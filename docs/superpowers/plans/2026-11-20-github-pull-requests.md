# GitHub Pull Requests Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A built-in launcher command `gh`: Tab (or Enter) shows the owner's open pull requests from the GitHub CLI, typing filters by title, Enter opens the PR in the default browser.

**Architecture:** UficastCore gets a `PullRequest` model with a JSON parser, a sort/filter function, a `gh` locator plus loader built on the existing `NativeRun` worker, and a `PullRequestStore` actor that shares one in-flight load and caches only success, for 5 minutes. The app target gets a pull-request mode in `LauncherPanelController` (its own mode that reuses the token, search field and results table) and routing in `AppController`.

**Tech Stack:** Swift 6 / AppKit, Swift Testing, the existing C `UficastProcess` worker. No new packages.

**Spec:** `docs/superpowers/specs/2026-11-20-github-pull-requests-design.md`

## Global Constraints

- No Accessibility, Input Monitoring or any new privacy grant. No shell is started; `gh` runs with exact argv. The filter text never reaches `gh`.
- `gh` argv exactly: `search prs --author @me --state open --sort created --order desc --limit 100 --json number,title,url,repository,createdAt,isDraft`. Timeout 30 s.
- `gh` is found on `PATH`: directories of the app's own `PATH`, then `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`; absolute, non-empty, de-duplicated; first regular executable file named `gh` wins. Child environment: app environment, that `PATH`, `GH_PROMPT_DISABLED=1`, `NO_COLOR=1`, `GH_NO_UPDATE_NOTIFIER=1`.
- Exact texts: not installed → `GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login.`; bad output → `Unexpected output from gh.`; empty list → `You have no open pull requests.`; loading → `Loading pull requests…`; no match → `No matching pull requests`; open failed → `Could not open the pull request.`; hints → `↑↓ Select  ·  ↩ Open  ·  Esc Back` (loaded), `Loading pull requests…  ·  Esc Back`, `Esc Back` (failure).
- Order: empty or blank filter → newest `createdAt` first; otherwise fuzzy score on the title, ties newest first. Wrong-layout variants apply to the filter query only.
- Cache lifetime: 300 s from the moment a load finishes (`PullRequestStore.defaultLifetime`). An older list counts as absent. `invalidate()` drops it at once.
- Pull-request data lives in memory only. Only the command's own usage counter (`builtin:gh`) is written to disk. Fixtures use fake `org/repo` data, never real PRs, URLs or names.
- Existing behavior of `caffeine`/`decaffeine`, scripts, calculator, alias precedence and Enter on other entries is unchanged.
- Tests: `TEST` = `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk scripts/test.sh --build-system native`. Native check build: `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk UFICAST_OUTPUT_ROOT="$PWD/.build/check" scripts/build.sh`, then run `.build/check/Uficast.app/Contents/MacOS/Uficast --verify-<name>` (PASS line, exit 0). See the toolchain note in `docs/plan/PROGRESS.md`.
- Commits: stage only the files of the task; end the message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; push with `git push origin main` after each verified commit. Never amend, rebase or force push.
- English UI and documents.

## Review Focus

1. `gh` present but failing (not signed in: non-zero exit and stderr only): the failure text is shown, nothing is cached, the next entry retries. → Task 2 `loaderMapsFailures`, Task 3 `failureIsNotCachedAndNextCallStartsFreshLoad`, Task 5 check "failure".
2. Odd `PATH` contents (empty entries, `.`, relative entries, `gh` being a directory or a non-executable file): such a `gh` is never run. → Task 2 `locateIgnoresUnsafeDirectoriesAndNonExecutables`.
3. Zero open PRs and a filter that matches nothing: distinct messages, Enter does nothing. → Task 1 `filterReturnsNothingForNoMatch`, Task 5 checks "empty" and "no match".
4. Leaving, hiding or re-entering during a load: late success is cached, late failure is silent, nothing reopens the panel or shows a stale error; a list older than 5 minutes is never shown as current. → Task 3 cancellation/sharing/expiry tests, Task 5 checks "late result" and "stale error".
5. Odd rows and queries: rows without repository or valid `createdAt`, non-http(s) URLs, emoji/Cyrillic titles, a blank filter, a Russian-layout query. → Task 1 parser and filter tests.

---

### Task 1: Model, parser, sort and filter

**Files:**
- Create: `Sources/UficastCore/PullRequest.swift`
- Modify: `Sources/UficastCore/SearchIndex.swift` (change `private static func fuzzyScore` to internal `static func fuzzyScore`; no other change)
- Modify: `Sources/UficastCore/LauncherEntry.swift` (add `case pullRequest` to `Kind`, title `"Pull Request"`)
- Test: `Tests/UficastCoreTests/PullRequestTests.swift`

**Interfaces:**
- Produces:
  - `public struct PullRequest: Identifiable, Hashable, Sendable` with `number: Int`, `title: String`, `url: URL`, `repository: String` (`owner/repo`), `createdAt: Date`, `isDraft: Bool`, `id: String { url.absoluteString }`, and a public memberwise `init(number:title:url:repository:createdAt:isDraft:)`.
  - `public enum PullRequestError: Error, LocalizedError, Equatable { case notInstalled, unexpectedOutput, failed(String), cancelled }` with the exact texts from Global Constraints (`failed` shows its message; `cancelled` shows `Cancelled.`).
  - `public protocol PullRequestLoading: Sendable { func load() async throws -> [PullRequest] }` (declared here, not in Task 2, so Tasks 2 and 3 can be built independently; no test of its own)
  - `public enum PullRequestParser { public static func parse(_ json: Data) throws -> [PullRequest] }`
  - `public enum PullRequestFilter { public static func apply(_ query: String, to pullRequests: [PullRequest]) -> [PullRequest] }`
  - `extension LauncherEntry { public static func pullRequest(_ pullRequest: PullRequest) -> LauncherEntry }`: id `"pr:" + url`, `name` = title, `kind` `.pullRequest`, `fileURL` = the PR URL, `alias` = `"<repository> #<number>"` plus `" · Draft"` for drafts.

- [ ] **Step 1: Write the failing tests** in `PullRequestTests.swift` (free `@Test` functions, `import Testing`, `import UficastCore`):
  - `parserReadsGhJsonAndDropsInvalidRows`: a JSON array of four rows in `gh`'s shape (`number`, `title`, `url`, `repository.nameWithOwner`, `createdAt` as `2026-11-19T01:54:48Z`, `isDraft`): a valid one, one with an empty title, one with URL `javascript:alert(1)`, one with URL `https:///x`, plus a valid draft. Expect exactly the two valid rows with their fields; `createdAt` equals the date computed by `ISO8601DateFormatter`; the draft flag is kept.
  - `parserRejectsNonArrayAndInvalidJson`: `{}`, `not json` and empty data throw `PullRequestError.unexpectedOutput`; `[]` returns `[]`.
  - `parserKeepsUnicodeTitlesAndDropsRowsMissingFields`: title `Исправить 🚀 "quotes"` is preserved exactly; a row without `repository`, and one with `createdAt` `"yesterday"`, are dropped (rows are decoded leniently one by one; only a non-array top level fails).
  - `filterBlankQueryOrdersNewestFirst`: three PRs with distinct dates and two with the same date; `""` and `"   "` both give newest first, equal dates by higher `number` first.
  - `filterFuzzyMatchesTitleAndTiesNewestFirst`: titles `Fix flaky retry in upload`, `Flaky cache test`, `Unrelated`; query `flaky` returns the first two and not the third. Two PRs titled `Fix cache` with different dates and query `fix` return the newer first.
  - `filterUsesWrongLayoutVariantsForTheQueryOnly`: query `аш` (typed on the Russian layout, equals `fi`) finds `Fix upload`; the Cyrillic title `Исправить` stays matchable by its own letters.
  - `filterReturnsNothingForNoMatch`: query `zzzz` returns `[]`.
  - `entryCarriesUrlKindAndLabels`: `LauncherEntry.pullRequest` of a draft with repository `org/api`, number 412 has kind `.pullRequest`, `fileURL` equal to the PR URL and alias `org/api #412 · Draft`.

- [ ] **Step 2: Run `TEST`; expect a compile failure** (types missing).

- [ ] **Step 3: Implement** the types in `PullRequest.swift`. Parser: decode `[Row]` with optional fields per row, dropping rows missing any required field, with an empty or whitespace-only title, or with a URL that is not absolute `http`/`https` with a non-empty host; `createdAt` via `ISO8601DateFormatter` (internet date-time). Filter: normalize titles with `SearchText.normalize`; get query variants from `KeyboardLayoutSearch.variants(_:)` exactly as `SearchIndex.search` uses them; score with `SearchIndex.fuzzyScore`, taking the best score across variants; sort by score descending, then `createdAt` descending, then `number` descending. A blank query skips scoring.

- [ ] **Step 4: Run `TEST`; expect all tests pass** (existing and new).

- [ ] **Step 5: Commit** (the spec and this plan were committed beforehand):
```bash
git add Sources/UficastCore/PullRequest.swift Sources/UficastCore/SearchIndex.swift Sources/UficastCore/LauncherEntry.swift Tests/UficastCoreTests/PullRequestTests.swift
git commit -m "feat: pull request model, parser, sort and filter"
git push origin main
```

### Task 2: Locate `gh` and load pull requests

**Files:**
- Create: `Sources/UficastCore/GitHubPullRequestLoader.swift`
- Test: `Tests/UficastCoreTests/GitHubPullRequestLoaderTests.swift` (use `@testable import UficastCore`, because `ScriptResult`'s memberwise init is internal)

**Interfaces:**
- Consumes: `PullRequest`, `PullRequestParser`, `PullRequestError`, `PullRequestLoading` (Task 1); `ScriptResult`, `NativeRun` (existing, same module).
- Produces:
  - `public enum GitHubCLI` with `static let standardDirectories: [String]`, `static let arguments: [String]` (the exact argv), `static func searchDirectories(path: String?) -> [String]` (app `PATH` entries first, then standard ones; absolute and non-empty only; de-duplicated keeping first position), `static func isRegularExecutable(_ path: String) -> Bool` (an existing regular file with an execute bit; a directory is false), `static func locate(in directories: [String], isExecutable: (String) -> Bool = GitHubCLI.isRegularExecutable) -> String?`.
  - `public struct GitHubPullRequestLoader: PullRequestLoading` with `typealias RunProcess = @Sendable (_ executable: String, _ arguments: [String], _ environment: [String: String], _ directory: String, _ timeout: Double) async throws -> ScriptResult` and `init(environment: [String: String] = ProcessInfo.processInfo.environment, isExecutable: @escaping @Sendable (String) -> Bool = GitHubCLI.isRegularExecutable, run: @escaping RunProcess = GitHubPullRequestLoader.runNative)`.

- [ ] **Step 1: Write the failing tests:**
  - `locateIgnoresUnsafeDirectoriesAndNonExecutables`: `searchDirectories(path: ":.:relative/bin:/a:/a:/b")` equals `["/a", "/b"]` followed by the standard directories not already present. In a temporary folder: a directory named `gh`, a file `gh` with mode 0o644, and a file `gh` with mode 0o755 in three folders; `locate` over those folders returns only the third path, and `nil` when only the first two are given.
  - `loaderRunsExactArgvWithPathAndQuietEnvironment`: fake `isExecutable` true only for `/fixture/bin/gh`, environment `PATH=/fixture/bin`; the recorded run has executable `/fixture/bin/gh`, arguments equal to `GitHubCLI.arguments`, `PATH` starting with `/fixture/bin:` and containing `/opt/homebrew/bin`, `GH_PROMPT_DISABLED`, `NO_COLOR` and `GH_NO_UPDATE_NOTIFIER` all `"1"`, timeout `30`; a valid JSON stdout yields the parsed PRs.
  - `loaderThrowsNotInstalledWithoutRunning`: `isExecutable` always false throws `.notInstalled`, the run closure is never called, and `errorDescription` equals the exact not-installed text.
  - `loaderMapsFailures`: exit code 4 with stderr `To get started with GitHub CLI, please run:  gh auth login` throws `.failed` whose message contains `Exit code 4` and that stderr; timed out throws `.failed("Timed out after 30 s.")`; cancelled throws `.cancelled`; `stdoutTruncated` and garbage stdout throw `.unexpectedOutput`.
  - `defaultRunnerExecutesAFakeGhFromPath`: write an executable shell script named `gh` into a temporary folder that prints one valid JSON row; `GitHubPullRequestLoader(environment: ["PATH": thatFolder])` with the default runner returns one PR. No real `gh` and no network are used.

- [ ] **Step 2: Run `TEST`; expect a compile failure.**

- [ ] **Step 3: Implement** in `GitHubPullRequestLoader.swift`. Default `runNative` follows `AITextRunner`: create a `NativeRun`, call `execute(executable:arguments:environment:directory:timeout:)` inside `withTaskCancellationHandler` that calls `cancel()`; map a spawn error (`ScriptRunError.system`) to `.failed(error.localizedDescription)`. Working directory: `FileManager.default.temporaryDirectory.path`. Failure mapping order: not installed, then termination (timed out, cancelled), then non-zero exit using `ScriptResult.failureDescription`, then truncation, then parse.

- [ ] **Step 4: Run `TEST`; expect all pass.**

- [ ] **Step 5: Commit**
```bash
git add Sources/UficastCore/GitHubPullRequestLoader.swift Tests/UficastCoreTests/GitHubPullRequestLoaderTests.swift
git commit -m "feat: find gh on PATH and load open pull requests"
git push origin main
```

### Task 3: Shared load and success-only cache

**Files:**
- Create: `Sources/UficastCore/PullRequestStore.swift`
- Test: `Tests/UficastCoreTests/PullRequestStoreTests.swift`

**Interfaces:**
- Consumes: `PullRequestLoading`, `PullRequest`, `PullRequestError` (Task 1).
- Produces: `public actor PullRequestStore` with `static let defaultLifetime: TimeInterval = 300`, `init(loader: any PullRequestLoading, lifetime: TimeInterval = PullRequestStore.defaultLifetime, now: @escaping @Sendable () -> Date = { Date() })`, `var cached: [PullRequest]? { get }` (nil when nothing is cached or the list is older than the lifetime), `func list() async throws -> [PullRequest]` (returns the cache, otherwise awaits one shared in-flight load; success is cached with the time the load finished, failure is not and the next call starts a fresh load), `func invalidate()` (drops the cached list at once; a load already running still caches its fresh result), `func cancel()` (cancels the in-flight load; nothing is cached).

- [ ] **Step 1: Write the failing tests** with a test-only `GatedLoader` actor (counts `load()` calls, suspends until the test releases a success or failure, throws `.cancelled` when its task is cancelled):
  - `concurrentCallsShareOneLoadAndSuccessIsCached`: two concurrent `list()` calls, one release; both return the same rows, load count is 1, a later `list()` returns at once with the count still 1 and `cached` is non-nil.
  - `failureIsNotCachedAndNextCallStartsFreshLoad`: the first load fails with `.failed("x")` and `list()` throws it; `cached` is nil; the second `list()` makes the load count 2 and succeeds.
  - `callerCancellationDoesNotCancelSharedLoad`: a caller task is cancelled while another caller waits; after release the waiting caller succeeds and the load count is 1.
  - `cancelStopsInFlightLoadWithoutCaching`: `cancel()` during a load makes `list()` throw `.cancelled`, `cached` stays nil and the next `list()` starts a fresh load.
  - `emptyListIsCached`: a loader returning `[]` gives `cached == []` and a second `list()` does not load again.
  - `cacheIsKeptWithinLifetime`: with a test clock, a `list()` 299 s after the load finishes does not load again and `cached` is non-nil.
  - `expiredCacheStartsFreshLoad`: with a test clock moved 301 s past the load, `cached` is nil, the next `list()` makes the load count 2 and returns the new rows, and the lifetime counts from that second load.
  - `invalidateClearsCache`: after a success, `invalidate()` makes `cached` nil and the next `list()` loads again; `invalidate()` during a running load does not stop that load from caching its result.

- [ ] **Step 2: Run `TEST`; expect a compile failure.**
- [ ] **Step 3: Implement** `PullRequestStore`: keep one unstructured `Task<[PullRequest], Error>`; callers await its value so their own cancellation does not cancel it; on completion store success and clear the task.
- [ ] **Step 4: Run `TEST`; expect all pass.**
- [ ] **Step 5: Commit**
```bash
git add Sources/UficastCore/PullRequestStore.swift Tests/UficastCoreTests/PullRequestStoreTests.swift
git commit -m "feat: share one pull request load and cache success for five minutes"
git push origin main
```

### Task 4: The built-in `gh` command

**Files:**
- Modify: `Sources/UficastCore/BuiltInCommand.swift`
- Modify: `Tests/UficastCoreTests/BuiltInCommandTests.swift`

**Interfaces:**
- Produces: `BuiltInCommand` gains `case pullRequests = "gh"`. Its `entry` has id `builtin:gh`, name `GitHub Pull Requests`, kind `.builtIn`, `fileURL` `uficast://command/gh`, alias `gh`; its `symbolName` is `arrow.triangle.pull`. `keepsAwake` stays true only for `caffeine` (so it is false for `pullRequests`; `AppController` must branch on `.pullRequests` before using it, see Task 6). `caffeine`/`decaffeine` entries are unchanged.

- [ ] **Step 1: Write the failing tests / update:** in the existing test change the last assertion to expect 4 distinct ids (three built-ins plus Notes). Add `ghFindsPullRequestsCommandByAliasNameFuzzyAndWrongLayout` (queries `gh`, `GH`, `github`, `pull`, `пр` all return the `pullRequests` entry first; `caffeine` still returns caffeine first; `BuiltInCommand(entryID: "builtin:gh") == .pullRequests`; its `keepsAwake` is false) and `userAliasGhOverridesBuiltInGh` (an app with user alias `gh` wins the query `gh` while `github` still returns the built-in).
- [ ] **Step 2: Run `TEST`; expect failures or a compile error.**
- [ ] **Step 3: Implement** the case and per-case entry data in `BuiltInCommand.swift`.
- [ ] **Step 4: Run `TEST`; expect all pass.**
- [ ] **Step 5: Commit**
```bash
git add Sources/UficastCore/BuiltInCommand.swift Tests/UficastCoreTests/BuiltInCommandTests.swift
git commit -m "feat: add the gh built-in command entry"
git push origin main
```

### Task 5: Pull-request mode in the launcher

**Files:**
- Modify: `Sources/Uficast/LauncherPanelController.swift` (state, layout constraints, key handling, `EntryRow.configure`, `verifyPullRequests`)
- Modify: `Sources/Uficast/Main.swift` (add the `--verify-pull-requests` flag in the style of `--verify-calculator`; PASS line `PASS: pull-request mode lists, filters, opens, leaves and ignores late results.`)

**Interfaces:**
- Consumes: `PullRequest`, `PullRequestFilter`, `LauncherEntry.pullRequest`, `BuiltInCommand.pullRequests` (Tasks 1, 4).
- Produces on `LauncherPanelController`:
  - `var openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }`
  - `@discardableResult func enterPullRequests(cached: [PullRequest]?) -> UUID?`: enters the mode; with a cached list shows it and returns nil; with nil shows the loading state and returns a load id.
  - `func finishPullRequestLoad(_ id: UUID, pullRequests: [PullRequest]?, error: String?)`: ignored unless the mode is active and `id` is the latest load id.

- [ ] **Step 1: Write `verifyPullRequests()` first** (a method of the controller next to `verifyCalculator`, same `check` helper style, fake `openURL`, fixture PRs on `org/api`, `org/web`; never touches the real browser or clipboard). It must check, with these labels:
  - "enter/loading": after typing `gh` and `enterPullRequests(cached: nil)`: token shows `gh`, filter field visible and empty, results empty, `emptyLabel` reads `Loading pull requests…`, hint is the loading hint, Enter calls `openURL` zero times.
  - "list": `finishPullRequestLoad` with three PRs: rows are newest first, row 0 selected, kinds are `.pullRequest`, alias text like `org/api #412`, hint is the loaded hint.
  - "filter": typing `flaky` narrows the rows and selects row 0; a Russian-layout query works; whitespace-only shows all; `zzzz` gives no rows, `emptyLabel` `No matching pull requests`, Enter does nothing ("no match").
  - "empty": `finishPullRequestLoad` with `[]` shows `You have no open pull requests.`, Enter does nothing.
  - "open": Enter on a row calls `openURL` once with that row's URL, the panel closes, `usage["builtin:gh"]` count is 1 and no `pr:` id is in `usage`, and reopening gives normal empty search.
  - "leave": Escape returns to normal search with the previous query restored (panel still visible); Backspace in an empty filter does the same; Tab inside the mode does nothing.
  - "late result": enter (load pending), `dismiss`, then `finishPullRequestLoad` with the old id: panel stays hidden, mode is off, view unchanged. Re-enter while loading: the old id is ignored, the new id is honoured.
  - "failure" and "stale error": `finishPullRequestLoad(id, nil, "Unexpected output from gh.")` shows the message in the failure area, hint `Esc Back`, Enter does nothing; after `dismiss` and `show` there is no error and no mode.
  - "open failed": `openURL` returning false keeps the panel open and shows `Could not open the pull request.` in the hint.
  - "draft query": an unfinished calculator draft typed before entering the mode survives hiding from inside the mode (`calculator.draft` uses the previous query, not the filter text).
- [ ] **Step 2: Build and run** the native check; expect a compile failure first (missing API), then, with stubs, FAIL.
- [ ] **Step 3: Implement** the mode. Pin these points, which are easy to get wrong:
  - State: `pullRequestMode`, `pullRequests`, `pullRequestLoadID`. Entering saves `previousQuery = field.stringValue` and clears the field; leaving goes through `returnToSearch`, which already restores `previousQuery`.
  - `clearArgument()` also resets all pull-request state, restores the field placeholder, constraints, and hides the failure area, so `dismiss` leaves the mode. In `dismiss`, the draft query is `previousQuery` when either argument or pull-request mode is active.
  - Layout: the token's leading constraint becomes `background.leadingAnchor + 24` (not tied to the field). Extract the field's leading constraint into a stored one (default active, `background + 24`) and add an inactive alternative `token.trailingAnchor + 12`; the mode swaps them. In the mode: token visible, field visible, `argumentScroll` hidden; field placeholder `Filter pull requests…`, accessibility label `Filter pull requests`.
  - `reloadResults` uses `PullRequestFilter.apply(field.stringValue, to: pullRequests).map(LauncherEntry.pullRequest)` in the mode. `controlTextDidChange` and `refreshHint` must not overwrite the mode's hint (`refreshHint` returns early in the mode).
  - Keys: Escape and Backspace-on-empty-field leave the mode; Tab is swallowed; `activateSelected` in the mode opens `results[table.selectedRow].fileURL` through `openURL` (nothing when there are no rows or a load is pending), then on success `recordUse(BuiltInCommand.pullRequests.entry.id)` and `dismiss(restoreFocus: false)`, on failure `showInputError("Could not open the pull request.")`.
  - Failure uses the existing failure area (label shown, Edit Input hidden, height 56).
  - `EntryRow.configure`: for `.pullRequest` use the SF Symbol `arrow.triangle.pull` and never call `IconStore`.
- [ ] **Step 4: Build and run** `--verify-pull-requests`; expect PASS, exit 0. Also run `--verify-calculator`, `--verify-usage-order`, `--verify-script-feedback` and `--verify-native-icons`; expect PASS.
- [ ] **Step 5: Commit**
```bash
git add Sources/Uficast/LauncherPanelController.swift Sources/Uficast/Main.swift
git commit -m "feat: pull-request mode in the launcher"
git push origin main
```

### Task 6: Wire the command into the app

**Files:**
- Modify: `Sources/Uficast/AppController.swift` (`launch`, `selectArgumentCommand`, a store property, the termination path)

**Interfaces:**
- Consumes: `PullRequestStore`, `GitHubPullRequestLoader` (Tasks 2–3), `enterPullRequests(cached:)`, `finishPullRequestLoad(_:pullRequests:error:)` (Task 5), `BuiltInCommand.pullRequests` (Task 4).
- Produces: `private let pullRequestStore = PullRequestStore(loader: GitHubPullRequestLoader())` and `private func openPullRequests()`.

- [ ] **Step 1: Implement** `openPullRequests()` as a `Task { @MainActor }`: read `await pullRequestStore.cached`; `guard let id = launcher.enterPullRequests(cached: cached) else { return }`; then `list()` and call `finishPullRequestLoad` with the list, or with the error's localized description; do nothing when `isTerminating`. Route to it from `launch(_:)` for `.builtIn` entries whose command is `.pullRequests`, placed before the Keep Awake guard so `keepsAwake` is never consulted, and from `selectArgumentCommand(_:)` (Tab) the same way. In the termination path where running scripts are cancelled, also `await pullRequestStore.cancel()`.
- [ ] **Step 2: Build** with the native check build command; expect success with no new warnings. Run all `--verify-*` flags from Task 5; expect PASS. `AppController` routing has no automated test; it is covered by the manual checks in Task 7.
- [ ] **Step 3: Commit**
```bash
git add Sources/Uficast/AppController.swift
git commit -m "feat: open pull-request mode from the gh command"
git push origin main
```

### Task 7: Documentation, full verification and install

**Files:**
- Modify: `docs/plan/REQUIREMENTS.md` (owner addition, November 20, 2026), `docs/plan/ARCHITECTURE.md` (new section), `docs/plan/PROGRESS.md` (new stage row and an "actual checks" block, unresolved issues, exact next step), `README.md` (one feature line), `docs/MANUAL_TESTS.md` (checklist)

- [ ] **Step 1: Write the docs** from the spec, in English, fake examples only. `PROGRESS.md` records only what was actually run, with counts. `MANUAL_TESTS.md` lists, all unchecked: real `gh` with real PRs (list order, filter, Enter opens the browser); signed-out `gh` (failure text, retry by re-entering); first Tab latency; Tab from the launcher after a normal quit and relaunch; the not-installed message is covered by unit tests only.
- [ ] **Step 2: Run `TEST`** (all pass; record the count) and every native check, including `--verify-pull-requests`.
- [ ] **Step 3: Commit and push** the docs:
```bash
git add docs/plan/REQUIREMENTS.md docs/plan/ARCHITECTURE.md docs/plan/PROGRESS.md docs/MANUAL_TESTS.md README.md
git commit -m "docs: record the gh pull requests command"
git push origin main
```
- [ ] **Step 4: Install** with the three-step procedure from `CLAUDE.md` (stage build, normal quit of the old app, copy over the bundle in `local/build.env`, open). Do not mark any manual check as passed.
