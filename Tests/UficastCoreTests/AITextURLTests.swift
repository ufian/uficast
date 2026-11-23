import Foundation
import Testing
import UficastCore

private func parse(_ text: String) -> AITextURL? { URL(string: text).flatMap { AITextURL.parse($0) } }

@Test func rewriteAndTranslateLinksCarryTheirTextPercentDecoded() {
    #expect(parse("uficast://rewrite?text=we%20was%20here") == AITextURL(action: .rewrite, text: "we was here"))
    #expect(parse("uficast://translate?text=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82") == AITextURL(action: .translate, text: "Привет"))
    #expect(parse("uficast://rewrite?text=a%0Ab%26c%3Dd%2Be")?.text == "a\nb&c=d+e")
    #expect(parse("uficast://rewrite?text=1+1")?.text == "1+1")
}

@Test func missingOrBlankTextMeansNoTextSoTheClipboardApplies() {
    #expect(parse("uficast://rewrite") == AITextURL(action: .rewrite, text: nil))
    #expect(parse("uficast://translate?text=") == AITextURL(action: .translate, text: nil))
    #expect(parse("uficast://rewrite?text=%20%0A%20") == AITextURL(action: .rewrite, text: nil))
    #expect(parse("uficast://rewrite?other=x") == AITextURL(action: .rewrite, text: nil))
}

@Test func onlyOurSchemeAndKnownActionsAreAccepted() {
    #expect(parse("uficast://launch?text=x") == nil)
    #expect(parse("uficast://?text=x") == nil)
    #expect(parse("https://rewrite?text=x") == nil)
    #expect(parse("shortcuts://rewrite?text=x") == nil)
    #expect(parse("UFICAST://REWRITE?text=x") == AITextURL(action: .rewrite, text: "x"))
}

@Test func theFirstTextParameterWinsAndOverlongTextIsFlagged() {
    #expect(parse("uficast://rewrite?text=one&text=two")?.text == "one")
    let long = String(repeating: "a", count: AITextURL.maximumTextLength + 1)
    #expect(parse("uficast://rewrite?text=\(long)")?.isTooLong == true)
    #expect(parse("uficast://rewrite?text=\(String(repeating: "a", count: AITextURL.maximumTextLength))")?.isTooLong == false)
}

@Test func theBuiltLinkPrefixIsWhatTheParserReads() {
    for action in AITextAction.allCases {
        let link = URL(string: AITextURL.prefix(for: action) + "hello%20world")
        #expect(link.flatMap { AITextURL.parse($0) } == AITextURL(action: action, text: "hello world"))
    }
}
