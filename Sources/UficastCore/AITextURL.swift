import Foundation

/// The `uficast://rewrite?text=…` and `uficast://translate?text=…` links that a Shortcut
/// opens. Any app or web page can open such a link, so a link only starts the same
/// request as the clipboard shortcut: the result is shown in Uficast's panel and
/// nothing is copied or inserted until the owner presses Enter.
public struct AITextURL: Equatable, Sendable {
    public static let scheme = "uficast"
    public static let maximumTextLength = 20_000

    public var action: AITextAction
    /// Nil when the link carries no text; the clipboard is used then.
    public var text: String?

    public init(action: AITextAction, text: String?) {
        self.action = action
        self.text = text
    }

    public var isTooLong: Bool { (text?.count ?? 0) > Self.maximumTextLength }

    /// Everything before the percent-encoded text; the Shortcut file appends the text to it.
    public static func prefix(for action: AITextAction) -> String { "\(scheme)://\(action.rawValue)?text=" }

    public static func parse(_ url: URL) -> AITextURL? {
        guard url.scheme?.lowercased() == scheme,
              let action = url.host(percentEncoded: false).flatMap({ AITextAction(rawValue: $0.lowercased()) }),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let value = components.queryItems?.first { $0.name == "text" }?.value
        let hasText = value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return AITextURL(action: action, text: hasText ? value : nil)
    }
}
