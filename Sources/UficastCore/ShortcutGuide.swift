import Foundation

/// Everything the owner needs to build "Rewrite/Translate with Uficast" in the Shortcuts app by
/// hand. Importing a generated `.shortcut` file does not work: Shortcuts refuses unsigned files
/// ("Importing unsigned shortcut files is not supported") and `shortcuts sign` needs an iCloud
/// sign-in, so Settings opens an empty shortcut and shows these steps instead.
public enum ShortcutGuide {
    public static func shortcutName(for action: AITextAction) -> String { "\(action.title) with Uficast" }

    /// For the "Run Shell Script" action with the shortcut's input passed on stdin. The text is
    /// percent-encoded byte by byte (UTF-8), so nothing in it can change the command or the link.
    public static func script(for action: AITextAction) -> String {
        let encode = #"perl -pe 's/([^A-Za-z0-9_.~-])/sprintf("%%%02X", ord($1))/ge'"#
        return "open \"\(AITextURL.prefix(for: action))$(\(encode))\""
    }

    public static func steps(for action: AITextAction) -> [String] {
        [
            "Click “Title” at the top left of the new shortcut and rename it to “\(shortcutName(for: action))”.",
            "Click ⓘ at the top right, turn on Use as Quick Action and choose Services Menu.",
            "In the first action (Receive … input from Quick Actions), set the type to Text and set “If there's no input” to Get Clipboard.",
            "Search Actions for Run Shell Script and add it. Set Pass Input to “to stdin” and paste the script (it is on your clipboard).",
            "In the ⓘ details, choose Add Keyboard Shortcut and press a combination with all of ⌃⌘⇧, such as ⌃⌘⇧R. A simpler one such as ⌃⌘R may belong to another app, and then the key silently does nothing.",
        ]
    }
}
