# AI text rewrite and translation

> **Update, November 20, 2026:** the macOS Services entry point described below was removed at the owner's request (it was not useful). Shortcuts that open `uficast://` links replace it; see REQUIREMENTS "AI text rewrite and translation" and ARCHITECTURE "Create Shortcut (Stage 6q)". Replacement of the selection and the Service deadline no longer exist.


Status: approved by the owner on November 19, 2026. Spike done (see the end).

## Intent

The owner writes English as a second language and reads/writes Russian. They want two keyboard actions on a piece of text from any app:

1. **Rewrite**: turn the text into correct, simple English.
2. **Translate**: English → Russian, or Russian → English.

The result is always shown first. Enter then puts the result in place of the selection where macOS allows it, and otherwise copies it to the clipboard. The AI backend is an owner-editable command line, `claude -p` with Claude Haiku 5.5 by default, so the owner can change the model or switch to another CLI such as Codex.

## Confirmed by the owner

- Two entry points for both actions: **clipboard** (owner copies, presses a Uficast hotkey) and **macOS Services** (owner selects, presses the Service's shortcut).
- Both show the result in Uficast. Enter substitutes the selection where possible, otherwise copies to the clipboard. Esc cancels.
- Translation also uses Haiku (not Apple Translation).
- The command (`claude -p …`) is editable in Settings, so the model can be changed by hand or the CLI replaced (e.g. Codex).
- Hard project rule still applies: no Accessibility or Input Monitoring, no keyboard observation.
- Both Services (Rewrite and Translate) behave the same: the Service takes the text, Uficast shows the result, Enter inserts it, Esc cancels.
- Formatting must be kept when the source has it (owner chose span markers through the model, option 1 below).

## Goals, non-goals, anti-goals

- Goals: the two actions through both entry points; an editable command with a working default; clear feedback while waiting and on failure.
- Non-goals: editable prompts, streaming output, languages other than English/Russian, automatic paste after copying, Apple on-device models, verifying Codex (not installed on this Mac), keeping formatting that a plain-text source never had, a Translate Service for read-only text (use the clipboard entry point there).
- Anti-goals:
  - Requesting Accessibility, posting synthetic keystrokes or watching the keyboard.
  - Putting the selected text into argv or into shell text (injection risk). It goes only through stdin.
  - Reading the clipboard without an explicit AI hotkey press.
  - Retrying automatically, or letting a late result change anything after the panel was dismissed.
  - Uficast itself writing the selected text or results to disk or logs. (What the configured CLI stores is governed by that CLI; see Builder decisions.)

## Constraints and facts found

- Without Accessibility an app cannot read another app's selection or paste into it. macOS Services can: the system sends the selection to the provider, and a Service that declares return types can send replacement text back.
- A Service that declares return types is enabled only where the requesting view can accept text back (editable text). On read-only text (a web page, a received email) it is disabled.
- Service shortcuts are assigned by the user in System Settings → Keyboard → Keyboard Shortcuts → Services. Uficast does not change system settings.
- The requesting app waits for a returning Service to answer, up to the Service's `NSTimeout`. While Uficast shows the result, that app does not respond.
- Many Electron apps and terminals do not support Services, or do not accept returned text. The clipboard entry point covers them.
- GUI apps get a minimal `PATH`; `claude` lives in `~/.local/bin`. `/bin/zsh -lc 'command -v claude'` finds it on this Mac.
- `claude --bare` needs an API key and does not read the OAuth login, so it is not usable here. `--tools ""`, `--strict-mcp-config`, `--disable-slash-commands`, `--no-session-persistence`, `--setting-sources` and `--system-prompt` exist in Claude Code 2.1.328. The owner's user settings define hooks (for example a prompt-submit hook that adds text to every prompt) and plugins; these must not change the output.
- The native process worker (`UficastProcess`) has no stdin support today. It gives timeouts, cancellation and process-group cleanup for scripts.

## Approaches considered

- **Service behavior.** (A) Wait for the result and the owner's Enter, then return the text, so macOS replaces the selection. (B) Return immediately and copy the result on Enter. **The owner chose:** show the result in both entry points; Enter substitutes where possible, otherwise copies. So returning Services use A, and the result is copied to the clipboard as well, in case the app ignores the returned text.
- **Translate Service.** (1) One Service without return types: works on read-only text too, but Enter only copies. (2) Two translate Services (copy and replace). (3) One returning Service, like Rewrite. **The owner chose (3):** every Service takes the text, shows the result, inserts on Enter. Consequence: the Translate Service is disabled on read-only text; there the owner copies and uses the clipboard hotkey.
- **Formatting.** (1) Span markers: mark each differently styled run, let the model keep the markers, restore each run's original attributes. (2) Base style only: the whole result gets the style at the start of the selection. **The owner chose (1)**, with (2) as the automatic fallback.
- **Passing text to the CLI.** (a) stdin; (b) a temporary file; (c) argv. **Chosen:** stdin, with the native worker extended to write it. (b) leaves text on disk; (c) is an injection and length risk.
- **Backend.** `claude -p` per request (owner's choice) rather than calling the API directly, which would need an API key the owner may not have.

## Design

**Configuration** (schema 1, all fields optional, absent = defaults):

- `aiText.command`: the shell command line. Default to be settled by the latency spike, starting from: `claude -p --model claude-haiku-5-5 --tools "" --strict-mcp-config --disable-slash-commands --no-session-persistence`.
- `aiText.rewriteHotkey`, `aiText.translateHotkey`: optional `GlobalShortcut`s for the clipboard entry point. Validated like other shortcuts and unique against the launcher and enabled app hotkeys.
- Validation: the command is non-empty, has no NUL and is at most 2,000 characters.

**Formatting (span markers).**

- Input: Services declare RTF and plain text as send and return types. The clipboard hotkey reads RTF, then HTML, then plain text from the general pasteboard. A plain-text source has no runs to keep.
- Marking: split the attributed string into attribute runs. If all runs share one style, send plain text (no markers). Otherwise wrap each run except those in the base style (the style at the start) as `<sN>…</sN>`, where N is the run's index, and keep the attribute dictionaries in memory. Escape literal `<` and `&` in the text so they cannot be read as markers.
- Prompt rule: keep every `<sN>` and `</sN>` around the words that carry that style in the result; markers may move, may not nest, be renamed or be invented. Links are runs like any other (their attributes include the URL).
- Restoring: parse the output strictly. Text outside markers gets the base style; text inside `<sN>` gets run N's attributes. If parsing fails (unknown, unbalanced, nested or invented markers), use the base-style fallback: the whole plain result in the base style, and show a small note "Formatting could not be kept" in the panel.
- Output: return/copy RTF and plain text (plain text without markers). The panel renders the attributed result.

**Running the command.**

- Execute `/bin/zsh -lc <command>` so the owner's login `PATH` applies. The working directory is a private empty folder under Uficast's Application Support, so no project instructions are picked up.
- The full prompt goes to stdin: built-in instructions plus the text. Contract: the command reads the prompt on stdin and prints only the answer on stdout. Trim surrounding whitespace from the output.
- Rewrite instructions: correct and simplify the English, keep the meaning, tone, names, line breaks, lists and the span markers, and output only the text. Translate instructions: if the text is mainly Russian, translate it into English, otherwise into Russian; keep line breaks, lists and the span markers; output only the translation.
- Timeout is 60 s. Esc or a new request cancels the running process. Use the native worker extended with a stdin buffer (written while stdout/stderr are drained, with no deadlock and no SIGPIPE crash), keeping its existing cleanup guarantees.
- Exactly one AI request at a time; a new one cancels the old one.

**Clipboard entry point.**

1. The hotkey reads plain text from the general pasteboard. If there is none, the panel says "Copy text first."
2. The panel shows the action and "Working…", then the result.
3. Enter copies the result to the general pasteboard and closes the panel. Esc closes it without changes.

**Services entry point.**

- Info.plist `NSServices`:
  - "Rewrite with Uficast" has send and return type plain text and `NSTimeout` of about 90,000 ms.
  - "Translate with Uficast" is the same, with its own message.
  - Uficast sets itself as the services provider at launch.
- Rewrite: the handler shows the panel and runs the request. It keeps the main run loop running until the owner presses Enter or Esc, or the deadline (just under `NSTimeout`) passes. On Enter it writes the result to the Service pasteboard and to the general pasteboard. On Esc or deadline it returns without writing, so nothing is replaced.
- Translate works exactly like Rewrite.
- General gets a short note and a button that opens Keyboard Shortcuts, where the owner assigns Service shortcuts.

**Panel.** Reuse the launcher panel in a new result mode:

- A token naming the action.
- A multi-line, scrollable, selectable result area.
- A hint: "↩ Replace · Esc Cancel" for a Service request, "↩ Copy · Esc Cancel" for the clipboard entry point.
- Errors (non-zero exit, timeout, empty output, command not found) show stderr-based text in the existing failure style. Retry is explicit only: pressing Enter on the error retries.
- Hiding the panel for any reason cancels the request and discards late results.
- If the Rewrite Service deadline passes while a result is shown, the panel stays open and switches to copy mode: the hint becomes "Time ran out for replacing · ↩ Copy · Esc Cancel". Nothing is replaced.

**Settings → General → "AI Text"** has:

- A monospaced Command field with Apply and Reset.
- Two hotkey recorders (Rewrite from clipboard, Translate from clipboard).
- The Services note and button.
- One line saying that the text is sent to whatever the command runs (Anthropic for `claude`).

## Builder decisions (my calls after the builder check; open to the owner's correction)

- **Privacy scope.** Uficast writes no text to disk or logs. The default command adds `--no-session-persistence` so Claude Code keeps no session, and the spike checks whether the owner's user hooks and plugins run; if they would add to the prompt or store text, the default also limits `--setting-sources` (keeping the OAuth login). A custom command (for example Codex) follows its own storage rules; the Settings privacy line says so.
- **Spike limits.** Go: median time to the answer ≤ 10 s and stdout holds only the answer. If the model name is rejected, use the name Claude Code accepts for Haiku 5.5 and record it. If the time is above 10 s or the output cannot be cleaned without losing the login, stop and ask the owner before building the Services part. The fallback offered then is a Rewrite Service that returns at once and copies on Enter.
- Second Service request during a Rewrite wait, input size cap, panel layout and launcher-hotkey behavior while a result is shown are left to the builder.

## Left to the builder

- Exact prompt wording, panel layout and sizes, hotkey ID ranges, file and type names, the exact marker escaping scheme and HTML import details.
- How the latency spike's numbers set the final default flags and whether `--setting-sources` or `--system-prompt` are needed to keep the owner's hooks, plugins and global CLAUDE.md out of the output.
- Documentation updates (REQUIREMENTS, ARCHITECTURE, IMPLEMENTATION_PLAN Stage 6n, PROGRESS, MANUAL_TESTS, README) and tests: config decode/validation, stdin worker (large input, early exit, cancellation), prompt assembly, output trimming, the stale-result rule, run marking and strict restoring (round trip, moved markers, broken markers → fallback, literal `<` in text, links).

## First step: spike before building

With the owner's approval, run the default command once on a neutral sentence (one Haiku call) through `/bin/zsh -lc` from an empty folder. Measure the time and check that stdout holds only the answer. Then try the flags above to keep hooks and plugins out. The numbers decide the default command and whether the Service timeout is enough. Also check, on one marked sample, whether Haiku keeps the span markers.

## Manual checks (not claimed until done)

- Clipboard rewrite and translate in an Electron app; Service rewrite and translate with replacement in Notes/Mail/Safari text fields; formatting kept for bold, italics and a link inside the selection; clipboard paste with formatting into Mail.
- Esc during "Working…" and while the result is shown, in both entry points.
- Command errors: wrong model name, missing CLI.
- A Codex command, if the owner installs Codex.

## Spike result (November 19, 2026, owner-approved, two Haiku calls)

Prompt: a rewrite instruction plus one English sentence with errors and two span markers, sent on stdin through `/bin/zsh -lc` from an empty folder.

| Variant | Time | stdout | Markers |
| --- | --- | --- | --- |
| `claude -p --model claude-haiku-5-5 --tools "" --strict-mcp-config --disable-slash-commands --no-session-persistence` | 5.14 s | only the rewritten sentence | kept |
| the same plus `--setting-sources project,local` | 2.78 s | only the rewritten sentence | kept |

Both passed the go limit (≤ 10 s, clean stdout); stderr was empty. The model ID `claude-haiku-5-5` was accepted, and the OAuth login worked without user settings. Two files under `~/.claude` changed during the spike (a plugin timer log and a plugin store file); neither contains the sample text. **Default command chosen:** the second variant, because it is faster and keeps the owner's user hooks and plugins out of the prompt. Two calls are not a latency distribution; the 10 s limit is still checked in daily use.
