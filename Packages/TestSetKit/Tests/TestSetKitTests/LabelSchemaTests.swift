import Foundation
import Testing
@testable import TestSetKit

@Suite("Label schema (FR-002)")
struct LabelSchemaTests {
    private func validate(_ dict: [String: Any], stem: String = "IMG_0001") -> Result<FrameLabels, LabelErrors> {
        LabelSchema.parse(dict, expectedID: stem)
    }

    private func fields(_ result: Result<FrameLabels, LabelErrors>) -> Set<String> {
        guard case .failure(let errors) = result else { return [] }
        return Set(errors.issues.map(\.field))
    }

    @Test func validLabelsParse() throws {
        let labels = try validate(FixtureSet.labels(id: "IMG_0001", [
            "light": ["mixed", "warm_indoor"], "pair_id": "latte-1", "notes": "fincan pencere önünde",
        ])).get()
        #expect(labels.id == "IMG_0001")
        #expect(labels.category == .cafeFood)
        #expect(labels.sceneType == .drinkCloseup)
        #expect(labels.light == [.mixed, .warmIndoor])
        #expect(labels.highlightsClipped == false)
        #expect(labels.compositionIssue == nil)
        #expect(labels.pairID == "latte-1")
        #expect(labels.notes == "fincan pencere önünde")
    }

    /// 2026-11-23: optional angle and light labels (spec 05 SC-007..SC-009); old files without them still parse.
    @Test func angleAndLightLabelsAreOptional() throws {
        let plain = try validate(FixtureSet.labels(id: "IMG_0001", [:])).get()
        #expect(plain.cameraAngle == nil && plain.lightDirection == nil && plain.lightQuality == nil)
        let labeled = try validate(FixtureSet.labels(id: "IMG_0001", [
            "camera_angle": "top_down", "light_direction": "left", "light_quality": "soft",
        ])).get()
        #expect(labeled.cameraAngle == .topDown)
        #expect(labeled.lightDirection == .left)
        #expect(labeled.lightQuality == .soft)
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["camera_angle": "low"]))) == ["camera_angle"])
    }

    /// 2026-11-25: optional series labels (spec 06 açık soru 4).
    @Test func seriesLabelsAreOptional() throws {
        let plain = try validate(FixtureSet.labels(id: "IMG_0001", [:])).get()
        #expect(plain.burstID == nil && plain.eyesClosedCount == nil)
        let labeled = try validate(FixtureSet.labels(id: "IMG_0001", ["burst_id": "walk-1", "eyes_closed_count": 1])).get()
        #expect(labeled.burstID == "walk-1" && labeled.eyesClosedCount == 1)
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["eyes_closed_count": -1]))) == ["eyes_closed_count"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["eyes_closed_count": 1.5]))) == ["eyes_closed_count"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["eyes_closed_count": true]))) == ["eyes_closed_count"])
    }

    @Test func missingRequiredFieldsAreAllReported() {
        let result = validate(FixtureSet.labels(id: "IMG_0001", ["exposure": nil, "sharpness": nil]))
        #expect(fields(result) == ["exposure", "sharpness"])
    }

    @Test func invalidEnumValueIsReported() {
        let result = validate(FixtureSet.labels(id: "IMG_0001", ["scene_type": "pizza"]))
        guard case .failure(let errors) = result else { Issue.record("expected failure"); return }
        #expect(errors.issues.count == 1)
        #expect(errors.issues[0].field == "scene_type")
        #expect(errors.issues[0].message.contains("pizza"))
    }

    @Test func wrongTypeIsReported() {
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["highlights_clipped": "no"]))) == ["highlights_clipped"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["light": "dim"]))) == ["light"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["notes": 3]))) == ["notes"])
    }

    @Test func lightMustBeNonEmptyAndUnique() {
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["light": [String]()]))) == ["light"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["light": ["dim", "dim"]]))) == ["light"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["light": ["dim", "sunny"]]))) == ["light"])
    }

    @Test func compositionIssueRequiredOnlyWhenBad() {
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["composition": "bad"]))) == ["composition_issue"])
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["composition_issue": "tilted"]))) == ["composition_issue"])
        let ok = validate(FixtureSet.labels(id: "IMG_0001", ["composition": "bad", "composition_issue": "tilted"]))
        #expect((try? ok.get())?.compositionIssue == .tilted)
    }

    @Test func unknownKeysAreRejected() {
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0001", ["exposre": "good"]))) == ["exposre"])
    }

    @Test func automaticFieldsMustNotBeWrittenByHand() {
        let result = validate(FixtureSet.labels(id: "IMG_0001", ["has_depth": true, "device": "iPhone 12", "lens": "x"]))
        #expect(fields(result) == ["has_depth", "device", "lens"])
    }

    @Test func idMustMatchFileName() {
        #expect(fields(validate(FixtureSet.labels(id: "IMG_0002"), stem: "IMG_0001")) == ["id"])
    }

    @Test func jsonSchemaCoversEveryManualField() throws {
        let data = try LabelSchema.jsonSchema()
        let schema = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(Set(properties.keys) == Set(LabelSchema.fields.map(\.key)))
        let required = try #require(schema["required"] as? [String])
        #expect(required.contains("scene_type"))
        #expect(!required.contains("notes"))
        #expect(schema["additionalProperties"] as? Bool == false)
        let scene = try #require(properties["scene_type"] as? [String: Any])
        #expect((scene["enum"] as? [String])?.contains("food_top_down") == true)
    }

    @Test func sceneTypesMatchSpec04List() {
        #expect(SceneType.allCases.map(\.rawValue) ==
            ["drink_closeup", "food_top_down", "food_angled", "table_spread", "cafe_interior", "other"])
    }
}
