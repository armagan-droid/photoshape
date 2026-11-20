import Foundation
import Testing
@testable import TestSetKit

@Suite("Test set loading and access (FR-003, FR-004, FR-005)")
struct TestSetTests {
    @Test func automaticFieldsComeFromTheFile() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001", depth: true)
        try fx.addFrame("IMG_0002", depth: false)

        let set = try TestSet.load(at: fx.root)
        let withDepth = try #require(set.frames.first { $0.id == "IMG_0001" })
        let without = try #require(set.frames.first { $0.id == "IMG_0002" })
        #expect(withDepth.metadata.hasDepth)
        #expect(!without.metadata.hasDepth)
        #expect(withDepth.metadata.device == "iPhone 12")
        #expect(withDepth.metadata.lens == "iPhone 12 back camera 4.2mm f/1.6")
        #expect(withDepth.metadata.pixelWidth == 64)
        #expect(withDepth.metadata.pixelHeight == 80)
    }

    @Test func depthMapAndImageLoad() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001", depth: true)
        let frame = try #require(try TestSet.load(at: fx.root).frames.first)

        let image = try frame.loadImage()
        #expect(image.width == 64 && image.height == 80)
        let depth = try #require(try frame.loadDepth())
        #expect(depth.kind == .disparity)
        #expect(depth.width == 16 && depth.height == 20)
        #expect(depth.values.count == 16 * 20)
        #expect(abs(depth.values[1] - (1.0 / 16 + 0.5)) < 0.001)
    }

    @Test func unlabeledFramesAreListedAndExcluded() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001")
        try fx.addImage("IMG_0002.heic")

        let set = try TestSet.load(at: fx.root)
        #expect(set.frames.map(\.id) == ["IMG_0001"])
        #expect(set.report.unlabeled == ["IMG_0002.heic"])
        #expect(set.report.isValid) // unlabeled frames are reported but are not label errors
    }

    @Test func invalidLabelsAreReportedWithFrameNameAndExcluded() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001")
        try fx.addFrame("IMG_0002", ["exposure": "dark"])
        try fx.addImage("IMG_0003.heic")
        try fx.addRaw("{ not json", named: "IMG_0003.json")

        let set = try TestSet.load(at: fx.root)
        #expect(set.frames.map(\.id) == ["IMG_0001"])
        #expect(!set.report.isValid)
        #expect(Set(set.report.issues.map(\.file)) == ["IMG_0002.json", "IMG_0003.json"])
        #expect(set.report.issues.contains { $0.file == "IMG_0002.json" && $0.field == "exposure" })
    }

    @Test func orphanLabelsAndDuplicateIDsAreErrors() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addLabels(FixtureSet.labels(id: "IMG_0009"), named: "IMG_0009.json")
        try fx.addImage("IMG_0001.heic", subdirectory: "a")
        try fx.addLabels(FixtureSet.labels(id: "IMG_0001"), named: "IMG_0001.json", subdirectory: "a")
        try fx.addImage("IMG_0001.jpg", subdirectory: "b")
        try fx.addLabels(FixtureSet.labels(id: "IMG_0001"), named: "IMG_0001.json", subdirectory: "b")

        let set = try TestSet.load(at: fx.root)
        #expect(set.report.orphanLabels == ["IMG_0009.json"])
        #expect(set.report.issues.contains { $0.field == "id" && $0.message.contains("duplicate") })
        #expect(set.frames.isEmpty)
    }

    @Test func twoImagesSharingOneLabelFileAreAmbiguous() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001")
        try fx.addImage("IMG_0001.jpg")
        let set = try TestSet.load(at: fx.root)
        #expect(set.frames.isEmpty)
        #expect(set.report.issues.contains { $0.file == "IMG_0001.json" && $0.message.contains("ambiguous") })
    }

    @Test func filteringIsByLabelAndDeterministic() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0005", ["light": ["dim", "warm_indoor"]])
        try fx.addFrame("IMG_0002", ["light": ["warm_indoor"]])
        try fx.addFrame("IMG_0003", ["light": ["dim", "warm_indoor"]])
        try fx.addFrame("IMG_0001", depth: true, ["light": ["dim"]])

        let set = try TestSet.load(at: fx.root)
        let dimWarm = set.frames { $0.labels.light.isSuperset(of: [.dim, .warmIndoor]) }
        #expect(dimWarm.map(\.id) == ["IMG_0003", "IMG_0005"])
        #expect(set.frames { $0.metadata.hasDepth }.map(\.id) == ["IMG_0001"])

        let again = try TestSet.load(at: fx.root)
        #expect(again.frames.map(\.id) == set.frames.map(\.id))
    }

    @Test func locateUsesEnvironmentVariable() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("IMG_0001")
        let set = try TestSet.locate(environment: ["PHOTOSHAPE_TESTSET": fx.root.path])
        #expect(set.frames.map(\.id) == ["IMG_0001"])
    }

    @Test func locateFindsTestSetDirectoryAboveStartPath() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        let nested = fx.root.appendingPathComponent("Packages/Brain/Tests/BrainTests", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let testSetDir = fx.root.appendingPathComponent("TestSet", isDirectory: true)
        try FileManager.default.createDirectory(at: testSetDir, withIntermediateDirectories: true)
        let set = try TestSet.locate(environment: [:], startingAt: nested.appendingPathComponent("X.swift").path)
        #expect(set.root.standardizedFileURL.path == testSetDir.standardizedFileURL.path)
    }
}
