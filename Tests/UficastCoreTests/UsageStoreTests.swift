import Foundation
import Testing
import UficastCore

private func app(_ name: String) -> LauncherEntry {
    LauncherEntry(id: "app:\(name.lowercased())", name: name, fileURL: URL(fileURLWithPath: "/fixture/\(name).app"))
}

@Test func recordingAUseCountsItAndRemembersWhen() {
    var record = UsageRecord()
    record.record(at: Date(timeIntervalSince1970: 100))
    record.record(at: Date(timeIntervalSince1970: 200))
    #expect(record.count == 2)
    #expect(record.lastUsed == Date(timeIntervalSince1970: 200))
}

@Test func usageSurvivesARestartAndStillOrdersTheEmptySearchByFrequency() {
    let index = SearchIndex(entries: [app("Alpha"), app("Beta"), app("Gamma")])
    #expect(index.search("").map(\.name) == ["Alpha", "Beta", "Gamma"])
    var usage: [String: UsageRecord] = [:]
    for _ in 0..<3 { usage["app:gamma", default: UsageRecord()].record(at: Date(timeIntervalSince1970: 10)) }
    usage["app:beta", default: UsageRecord()].record(at: Date(timeIntervalSince1970: 20))
    let restored = UsageStore.decode(UsageStore.encode(usage))
    #expect(restored == usage)
    #expect(index.search("", usage: restored).map(\.name) == ["Gamma", "Beta", "Alpha"])
}

@Test func equalCountsFallBackToTheMoreRecentUse() {
    let index = SearchIndex(entries: [app("Alpha"), app("Beta")])
    let usage = UsageStore.decode(UsageStore.encode([
        "app:alpha": UsageRecord(count: 2, lastUsed: Date(timeIntervalSince1970: 10)),
        "app:beta": UsageRecord(count: 2, lastUsed: Date(timeIntervalSince1970: 99)),
    ]))
    #expect(index.search("", usage: usage).map(\.name) == ["Beta", "Alpha"])
}

@Test func missingOrCorruptStoredUsageStartsEmpty() {
    #expect(UsageStore.decode(nil).isEmpty)
    #expect(UsageStore.decode(Data("not json".utf8)).isEmpty)
    #expect(UsageStore.decode(Data("[1,2,3]".utf8)).isEmpty)
}

@Test func storedUsageDropsNonsenseCountsAndKeepsOnlyTheMostRecentEntries() throws {
    let negative = Data(#"{"app:x":{"count":-4,"lastUsed":0},"app:y":{"count":2,"lastUsed":5}}"#.utf8)
    #expect(UsageStore.decode(negative).keys.sorted() == ["app:y"])
    var usage: [String: UsageRecord] = [:]
    for number in 0..<(UsageStore.limit + 25) {
        usage["app:\(number)"] = UsageRecord(count: 1, lastUsed: Date(timeIntervalSince1970: Double(number)))
    }
    let restored = UsageStore.decode(UsageStore.encode(usage))
    #expect(restored.count == UsageStore.limit)
    #expect(restored["app:0"] == nil)
    #expect(restored["app:\(UsageStore.limit + 24)"] != nil)
}

@Test func storedUsageHoldsOnlyIdentifiersCountsAndDates() throws {
    let data = try #require(UsageStore.encode(["app:notes": UsageRecord(count: 3, lastUsed: Date(timeIntervalSince1970: 7))]))
    let text = try #require(String(data: data, encoding: .utf8))
    #expect(text.contains("app:notes"))
    #expect(!text.contains("/"))
}
