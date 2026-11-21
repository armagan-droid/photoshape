import Foundation
import Testing
@testable import LookKit

@Suite("Look recipe format v1 (FR-001)")
struct RecipeTests {
    static let minimal = #"""
    {
      "format": 1, "id": "test-look", "version": 2,
      "name": {"tr": "Deneme", "en": "Test"},
      "summary": {"tr": "Deneme görünümü", "en": "Test look"},
      "category": "cafe_food", "sceneTypes": ["drink_closeup"],
      "adjustments": {"exposure": 0.2, "temperature": 0.3, "ranges": {"orange": {"saturation": 0.4}}},
      "access": "free", "source": "bundled"
    }
    """#

    @Test func decodesWithDefaults() throws {
        let recipe = try LookRecipe.decode(Data(Self.minimal.utf8))
        #expect(recipe.id == "test-look" && recipe.version == 2)
        #expect(recipe.name.tr == "Deneme" && recipe.name.en == "Test")
        #expect(recipe.adjustments.exposure == 0.2)
        #expect(recipe.adjustments.contrast == 0, "missing values default to 0")
        #expect(recipe.adjustments.ranges[.orange]?.saturation == 0.4)
        #expect(recipe.adjustments.ranges[.orange]?.hue == 0)
        #expect(recipe.blur == .none)
        #expect(recipe.sample == nil)
        #expect(recipe.access == .free && recipe.source == .bundled)
    }

    @Test func roundTripsThroughJSON() throws {
        let recipe = try LookRecipe.decode(Data(Self.minimal.utf8))
        #expect(try LookRecipe.decode(recipe.encoded()) == recipe)
    }

    @Test func ignoresUnknownFieldsForForwardCompatibility() throws {
        let json = Self.minimal.replacingOccurrences(of: #""access": "free""#, with: #""access": "free", "futureField": {"x": 1}"#)
        #expect(try LookRecipe.decode(Data(json.utf8)).id == "test-look")
    }

    @Test func rejectsUnsupportedFormatAndOutOfRangeValues() {
        let future = Self.minimal.replacingOccurrences(of: #""format": 1"#, with: #""format": 2"#)
        #expect(throws: LookRecipe.ValidationError.self) { try LookRecipe.decode(Data(future.utf8)) }
        let extreme = Self.minimal.replacingOccurrences(of: #""exposure": 0.2"#, with: #""exposure": 3"#)
        #expect(throws: LookRecipe.ValidationError.self) { try LookRecipe.decode(Data(extreme.utf8)) }
        let noName = Self.minimal.replacingOccurrences(of: #""en": "Test""#, with: #""en": """#)
        #expect(throws: LookRecipe.ValidationError.self) { try LookRecipe.decode(Data(noName.utf8)) }
        #expect(throws: (any Error).self) { try LookRecipe.decode(Data("{ broken".utf8)) }
    }

    @Test func strengthScalesEveryValue() throws {
        let a = try LookRecipe.decode(Data(Self.minimal.utf8)).adjustments
        let half = a.scaled(by: 0.5)
        #expect(half.exposure == 0.1 && half.temperature == 0.15)
        #expect(half.ranges[.orange]?.saturation == 0.2)
        #expect(a.scaled(by: 0) == .zero)
        #expect(a.scaled(by: 1) == a)
    }

    @Test func naturalIsTheIdentityLook() {
        #expect(LookRecipe.natural.id == "natural")
        #expect(LookRecipe.natural.adjustments == .zero)
        #expect(LookRecipe.natural.access == .free)
    }
}

@Suite("Color science (ΔE2000)")
struct ColorScienceTests {
    // Sharma, Wu & Dalal (2005) test data.
    @Test(arguments: [
        (Lab(50, 2.6772, -79.7751), Lab(50, 0, -82.7485), 2.0425),
        (Lab(50, 3.1571, -77.2803), Lab(50, 0, -82.7485), 2.8615),
        (Lab(50, 2.8361, -74.0200), Lab(50, 0, -82.7485), 3.4412),
        (Lab(50, -1.3802, -84.2814), Lab(50, 0, -82.7485), 1.0000),
        (Lab(50, 0, 0), Lab(50, -1, 2), 2.3669),
        (Lab(2.0776, 0.0795, -1.1350), Lab(0.9033, -0.0636, -0.5514), 0.9082),
    ])
    func matchesPublishedValues(a: Lab, b: Lab, expected: Double) {
        #expect(abs(ColorScience.deltaE2000(a, b) - expected) < 1e-4)
    }

    @Test func sRGBWhiteAndBlack() {
        let white = ColorScience.lab(fromSRGB: (1, 1, 1))
        #expect(abs(white.l - 100) < 0.01 && abs(white.a) < 0.01 && abs(white.b) < 0.01)
        #expect(abs(ColorScience.lab(fromSRGB: (0, 0, 0)).l) < 0.01)
    }
}
