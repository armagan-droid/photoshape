import Foundation
import Testing
@testable import TestSetKit

@Suite("Region labels (FR-008, FR-009)")
struct RegionTests {
    private let box: [String: Any] = ["x": 0.1, "y": 0.2, "w": 0.3, "h": 0.4]

    private func fields(_ overrides: [String: Any?]) -> Set<String> {
        guard case .failure(let e) = LabelSchema.parse(FixtureSet.labels(id: "A", overrides), expectedID: "A") else { return [] }
        return Set(e.issues.map(\.field))
    }

    private func parse(_ overrides: [String: Any?]) throws -> FrameLabels {
        try LabelSchema.parse(FixtureSet.labels(id: "A", overrides), expectedID: "A").get()
    }

    // MARK: Validation (FR-008)

    @Test func validRegionsParse() throws {
        let labels = try parse(["subject_region": box, "neutral_region": [box, ["x": 0, "y": 0, "w": 1, "h": 1]]])
        #expect(labels.subjectRegion == Region(x: 0.1, y: 0.2, w: 0.3, h: 0.4))
        #expect(labels.neutralRegions.count == 2)
        #expect(labels.neutralRegions[1] == Region(x: 0, y: 0, w: 1, h: 1))
    }

    @Test(arguments: [
        #"{"x": 0.8, "y": 0.2, "w": 0.3, "h": 0.4}"#,         // x + w > 1
        #"{"x": 0.1, "y": -0.1, "w": 0.3, "h": 0.4}"#,        // negative
        #"{"x": 0.1, "y": 0.2, "w": 0, "h": 0.4}"#,           // zero width
        #"{"x": 0.1, "y": 0.2, "w": 0.3}"#,                   // missing h
        #"{"x": 0.1, "y": 0.2, "w": 0.3, "h": 0.4, "z": 1}"#, // extra key
        #"{"x": "0.1", "y": 0.2, "w": 0.3, "h": 0.4}"#,       // string
        #"{"x": true, "y": 0.2, "w": 0.3, "h": 0.4}"#,        // bool
    ])
    func invalidSubjectRegionIsRejected(json: String) throws {
        let region = try JSONSerialization.jsonObject(with: Data(json.utf8))
        #expect(fields(["subject_region": region]) == ["subject_region"])
    }

    @Test func roundingToleranceAtTheEdge() throws {
        let labels = try parse(["subject_region": ["x": 0.7, "y": 0.6, "w": 0.3000000001, "h": 0.4]])
        #expect(labels.subjectRegion != nil)
    }

    @Test func neutralRegionMustBeANonEmptyArrayOfValidRegions() {
        #expect(fields(["neutral_region": box]) == ["neutral_region"])
        #expect(fields(["neutral_region": [Any]()]) == ["neutral_region"])
        #expect(fields(["neutral_region": [box, ["x": 0.9, "y": 0, "w": 0.2, "h": 0.1]]]) == ["neutral_region"])
    }

    // MARK: Conditional requirement (gaps)

    @Test func subjectExpectedUnlessSceneHasNoMainSubject() throws {
        for scene in SceneType.allCases {
            let gaps = LabelSchema.gaps(for: try parse(["scene_type": scene.rawValue])).map(\.field)
            let expected = scene == .cafeInterior || scene == .other ? [] : ["subject_region"]
            #expect(gaps == expected, "\(scene)")
        }
    }

    @Test func neutralExpectedUnderWarmOrMixedLight() throws {
        func gaps(_ light: [String], neutral: Bool = false) throws -> [String] {
            LabelSchema.gaps(for: try parse(["scene_type": "other", "light": light,
                                             "neutral_region": neutral ? [box] : nil])).map(\.field)
        }
        #expect(try gaps(["warm_indoor"]) == ["neutral_region"])
        #expect(try gaps(["window_daylight", "mixed"]) == ["neutral_region"])
        #expect(try gaps(["window_daylight"]) == [])
        #expect(try gaps(["mixed"], neutral: true) == [])
    }

    @Test func regionFieldsAreOptionalInJSONSchema() throws {
        let schema = try #require(try JSONSerialization.jsonObject(with: LabelSchema.jsonSchema()) as? [String: Any])
        let required = try #require(schema["required"] as? [String])
        #expect(!required.contains("subject_region") && !required.contains("neutral_region"))
        let props = try #require(schema["properties"] as? [String: Any])
        let neutral = try #require(props["neutral_region"] as? [String: Any])
        #expect(neutral["type"] as? String == "array")
        #expect((neutral["description"] as? String)?.contains("warm_indoor") == true)
    }

    // MARK: Marking by dragging (FR-009)

    @Test func dragIsNormalizedAgainstTheShownImage() {
        // Image drawn at (100, 50) with size 400×500 inside the view.
        let r = Region.fromDrag(start: (300, 300), end: (140, 100), imageFrame: (100, 50, 400, 500))
        #expect(r == Region(x: 0.1, y: 0.1, w: 0.4, h: 0.4))
    }

    @Test func dragOutsideTheImageIsClampedAndTinyDragsIgnored() {
        let r = Region.fromDrag(start: (0, 0), end: (300, 9999), imageFrame: (100, 50, 400, 500))
        #expect(r == Region(x: 0, y: 0, w: 0.5, h: 1))
        #expect(Region.fromDrag(start: (200, 200), end: (201, 260), imageFrame: (100, 50, 400, 500)) == nil)
    }

    @Test func pixelRectCoversTheRegion() {
        let p = Region(x: 0.1, y: 0.25, w: 0.5, h: 0.5).pixelRect(width: 64, height: 80)
        #expect(p.x == 6 && p.y == 20 && p.w == 33 && p.h == 40)
    }

    // MARK: Writing label files

    @Test func settingRegionsKeepsOtherFieldsAndValidates() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        try fx.addFrame("A", ["light": ["warm_indoor"], "notes": "çay bardağı"])
        let url = fx.root.appendingPathComponent("A.json")
        let subject = Region(x: 0.2, y: 0.3, w: 0.4, h: 0.35)
        let neutral = [Region(x: 0.05, y: 0.6, w: 0.1, h: 0.1)]

        try LabelFile.setRegions(subject: subject, neutral: neutral, at: url)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("\"subject_region\": {\"x\": 0.2, \"y\": 0.3, \"w\": 0.4, \"h\": 0.35}"))
        #expect(text.contains("çay bardağı"))
        // Schema order: scene_type before subject_region before people_visible before notes.
        let order = ["\"scene_type\"", "\"subject_region\"", "\"neutral_region\"", "\"people_visible\"", "\"notes\""]
            .map { text.range(of: $0)!.lowerBound }
        #expect(order == order.sorted())

        let set = try TestSet.load(at: fx.root)
        #expect(set.report.isValid && set.report.gaps.isEmpty)
        #expect(set.frames[0].labels.subjectRegion == subject)
        #expect(set.frames[0].labels.neutralRegions == neutral)

        try LabelFile.setRegions(subject: nil, neutral: [], at: url)
        let cleared = try LabelFile.readDictionary(at: url)
        #expect(cleared["subject_region"] == nil && cleared["neutral_region"] == nil)
        #expect(cleared["notes"] as? String == "çay bardağı")
    }

    @Test func settingRegionsCreatesAMissingLabelFile() throws {
        let fx = try FixtureSet(); defer { fx.remove() }
        let url = fx.root.appendingPathComponent("IMG_0042.json")
        try LabelFile.setRegions(subject: Region(x: 0, y: 0, w: 1, h: 1), neutral: [], at: url)
        let dict = try LabelFile.readDictionary(at: url)
        #expect(dict["id"] as? String == "IMG_0042")
        #expect(LabelFile.regions(in: dict).subject == Region(x: 0, y: 0, w: 1, h: 1))
    }
}
