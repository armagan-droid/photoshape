import Foundation
import Testing
@testable import TestSetKit

@Suite("Coverage report (Hikâye 3, SC-001, SC-002)")
struct CoverageTests {
    @Test func distributionCountsEveryValue() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("A", ["light": ["dim", "warm_indoor"]])
        try fx.addFrame("B", ["light": ["dim"], "exposure": "under"])
        try fx.addFrame("C", depth: true)

        let report = CoverageReport(try TestSet.load(at: fx.root))
        #expect(report.frameCount == 3)
        #expect(report.distribution["light"]?["dim"] == 2)
        #expect(report.distribution["light"]?["warm_indoor"] == 1)
        #expect(report.distribution["light"]?["backlit"] == 0)
        #expect(report.distribution["exposure"]?["under"] == 1)
        #expect(report.distribution["has_depth"]?["true"] == 1)
        #expect(report.distribution["has_depth"]?["false"] == 2)
    }

    @Test func quotasFromSpecTable() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        for i in 0..<5 { try fx.addFrame("D\(i)", ["light": ["dim"]]) }
        for i in 0..<4 { try fx.addFrame("M\(i)", ["light": ["mixed"]]) }

        let report = CoverageReport(try TestSet.load(at: fx.root))
        #expect(report.quota("light_dim")?.actual == 5)
        #expect(report.quota("light_dim")?.isMet == true)
        #expect(report.quota("light_mixed")?.actual == 4)
        #expect(report.quota("light_mixed")?.isMet == false)
        #expect(report.quota("has_depth")?.required == 10)
        #expect(!report.allQuotasMet)
    }

    @Test func everyCompositionIssueAndSceneTypeHasItsOwnQuota() {
        let ids = Set(Quota.spec00.map(\.id))
        for issue in CompositionIssue.allCases { #expect(ids.contains("composition_issue_\(issue.rawValue)")) }
        for scene in SceneType.allCases where scene != .other { #expect(ids.contains("scene_type_\(scene.rawValue)")) }
        #expect(!ids.contains("scene_type_other"))
        #expect(Quota.spec00.first { $0.id == "composition_bad" }?.required == 8)
    }

    @Test func pairQuotaCountsGoodBadGroups() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        // exposure pair
        try fx.addFrame("P1a", ["pair_id": "p1"])
        try fx.addFrame("P1b", ["pair_id": "p1", "exposure": "over"])
        // composition pair
        try fx.addFrame("P2a", ["pair_id": "p2"])
        try fx.addFrame("P2b", ["pair_id": "p2", "composition": "bad", "composition_issue": "tilted"])
        // not a good/bad pair: both good
        try fx.addFrame("P3a", ["pair_id": "p3"])
        try fx.addFrame("P3b", ["pair_id": "p3"])
        // single frame group
        try fx.addFrame("P4a", ["pair_id": "p4", "exposure": "under"])

        let report = CoverageReport(try TestSet.load(at: fx.root))
        #expect(report.quota("good_bad_pairs")?.actual == 2)
        #expect(report.quota("good_bad_pairs")?.required == 5)
    }

    @Test func minimumFrameCountGate() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("A")
        let report = CoverageReport(try TestSet.load(at: fx.root))
        #expect(report.quota("min_frames")?.required == 30)
        #expect(report.quota("min_frames")?.actual == 1)
    }

    @Test func fiftyFrameSetValidatesWellUnderTenSeconds() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        for i in 0..<50 { try fx.addFrame(String(format: "IMG_%04d", i), depth: i.isMultiple(of: 3)) }
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            let set = try TestSet.load(at: fx.root)
            _ = CoverageReport(set)
            #expect(set.frames.count == 50)
        }
        #expect(elapsed < .seconds(10))
    }
}
