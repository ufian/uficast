import Foundation
import Testing
import UficastCore

@Test func caffeineCommandsMatchNamesAbbreviationsFuzzyAndWrongLayout() {
    let index = SearchIndex(entries: BuiltInCommand.entries + [
        LauncherEntry(id: "app:notes", name: "Notes", fileURL: URL(fileURLWithPath: "/fixture/Notes.app")),
    ])
    for query in ["caffeine", "cafe", "caff", "cfn", "CAFE", "сфау"] {
        #expect(index.search(query).first?.id == BuiltInCommand.caffeine.entry.id)
    }
    for query in ["decaffeine", "decafe", "decaff", "dcfn", "DECAFE", "вусфау"] {
        #expect(index.search(query).first?.id == BuiltInCommand.decaffeine.entry.id)
    }
    #expect(BuiltInCommand(entryID: "builtin:caffeine")?.keepsAwake == true)
    #expect(BuiltInCommand(entryID: "builtin:decaffeine")?.keepsAwake == false)
    #expect(BuiltInCommand(entryID: "app:caffeine") == nil)
    #expect(BuiltInCommand(entryID: "builtin:unknown") == nil)
    #expect(Set(index.search("").map(\.id)).count == 4)
}

@Test func userAliasCanOverrideBuiltInAbbreviationWithoutChangingConfiguration() throws {
    var config = Configuration()
    config.applications["app:custom"] = AppOverride(alias: "cafe")
    let entry = LauncherEntry(id: "app:custom", name: "Zebra", fileURL: URL(fileURLWithPath: "/fixture/Zebra.app"))
    let index = SearchIndex(entries: try config.validated().entries(catalog: [entry]) + BuiltInCommand.entries)
    #expect(index.search("cafe").first?.id == "app:custom")
    #expect(index.search("caffeine").first?.id == BuiltInCommand.caffeine.entry.id)
}

@Test func ghFindsPullRequestsCommandByAliasNameFuzzyAndWrongLayout() {
    let index = SearchIndex(entries: BuiltInCommand.entries + [
        LauncherEntry(id: "app:notes", name: "Notes", fileURL: URL(fileURLWithPath: "/fixture/Notes.app")),
    ])
    for query in ["gh", "GH", "github", "pull", "пр"] {
        #expect(index.search(query).first?.id == BuiltInCommand.pullRequests.entry.id)
    }
    #expect(index.search("caffeine").first?.id == BuiltInCommand.caffeine.entry.id)
    #expect(BuiltInCommand(entryID: "builtin:gh") == .pullRequests)
    #expect(BuiltInCommand.pullRequests.keepsAwake == false)
}

@Test func userAliasGhOverridesBuiltInGh() throws {
    var config = Configuration()
    config.applications["app:custom"] = AppOverride(alias: "gh")
    let entry = LauncherEntry(id: "app:custom", name: "Zebra", fileURL: URL(fileURLWithPath: "/fixture/Zebra.app"))
    let index = SearchIndex(entries: try config.validated().entries(catalog: [entry]) + BuiltInCommand.entries)
    #expect(index.search("gh").first?.id == "app:custom")
    #expect(index.search("github").first?.id == BuiltInCommand.pullRequests.entry.id)
}

private func ghFixtureEntries(withGimp: Bool = false) -> [LauncherEntry] {
    var entries = BuiltInCommand.entries + [
        LauncherEntry(id: "app:ghostty", name: "Ghostty", fileURL: URL(fileURLWithPath: "/fixture/Ghostty.app")),
        LauncherEntry(id: "app:chrome", name: "Google Chrome", fileURL: URL(fileURLWithPath: "/fixture/Chrome.app")),
    ]
    if withGimp {
        entries.append(LauncherEntry(id: "app:gimp", name: "Gimp", fileURL: URL(fileURLWithPath: "/fixture/Gimp.app")))
    }
    return entries
}

@Test func gAloneDoesNotSelectTheGhCommand() {
    let usage = ["app:chrome": UsageRecord(count: 3, lastUsed: Date(timeIntervalSince1970: 100))]
    let index = SearchIndex(entries: ghFixtureEntries())
    #expect(index.search("g", usage: usage).first?.id == "app:chrome")
    let withGimp = SearchIndex(entries: ghFixtureEntries(withGimp: true))
    let gimpUsage = usage.merging(["app:gimp": UsageRecord(count: 1, lastUsed: Date(timeIntervalSince1970: 50))]) { $1 }
    #expect(withGimp.search("gi", usage: gimpUsage).first?.id != "builtin:gh")
}

@Test func ghStillRanksTheCommandFirstByExactAlias() {
    let index = SearchIndex(entries: ghFixtureEntries())
    #expect(index.search("gh").first?.id == "builtin:gh")
    #expect(index.search("пр").first?.id == "builtin:gh")
}

@Test func caffeinePrefixAbbreviationsAreUnchanged() {
    let index = SearchIndex(entries: ghFixtureEntries())
    #expect(index.search("caf").first?.id == BuiltInCommand.caffeine.entry.id)
    #expect(index.search("decaf").first?.id == BuiltInCommand.decaffeine.entry.id)
}
