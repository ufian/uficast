# README screenshots

These PNGs capture actual Uficast AppKit/SwiftUI views rendered offscreen with public demonstration data, not the owner's configuration or desktop.

Last regenerated and visually reviewed: November 23, 2026. The views are real; the content and settings are demonstration fixtures.

- `launcher.png`: Calculator, Calendar, Notes, Safari and Terminal, with example aliases.
- `commands.png`: the same apps plus a generic script; the Terminal shortcut is an example only.
- `error.png`: generic fixture failure and Edit Input action; no actual script ran for this capture.
- `argument.png`: dark appearance with a generic script and the literal argument `release notes`.
- `general.png`: compact General cards with default fixture settings, not the owner's preferences.
- `calculator.png`: `24*3` → `72` and fixed example history.
- `pull-requests.png`: three fictional pull requests in `demo/launcher` and `demo/docs`, including one draft. All URLs use example.com; no GitHub request is made.
- `ai-text.png`: a fixed Russian translation in the real dark result panel; no AI command is run.

App/script/PR fixtures are defined in `Sources/Uficast/ViewPreview.swift`; calculator fixtures are in `LauncherPanelController.renderPreview`, and AI text is in `AITextPanelController.renderPreview`. Only the fixed standard-app paths are used for icons; there is no catalog discovery, personal configuration load, script execution, GitHub/AI command, clipboard read/write, hotkey registration or system setting change. Preview state does not describe actual startup, remapping or power settings.

From the repository root:

```sh
scripts/build.sh
scripts/screenshots.sh
```

Quit before replacing a running bundle, or build with `UFICAST_OUTPUT_ROOT` and pass that `.app` path to the screenshot script. Visually inspect every regenerated image before committing it.
