import CoreImage
import Foundation
import Testing
@testable import LookKit

@Suite("Matching the scene to an example photo (spec 05 FR-009, FR-010, SC-001, SC-002)")
struct MatchingTests {
    static let scene = Fixture.scene(width: 400, height: 500)
    static let renderer = LookRenderer()

    static func cg(_ image: CIImage) -> CGImage {
        Fixture.context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: Fixture.sRGB)!
    }

    static func applied(_ adjustments: LookAdjustments, to image: CIImage) -> CIImage {
        var recipe = LookRecipe.natural
        recipe.adjustments = adjustments
        return renderer.render(image, recipe: recipe, strength: 1)
    }

    @Test func sameSceneAsExampleNeedsAlmostNothing() throws {
        let sample = try #require(SceneSample(image: Self.cg(Self.scene)))
        let result = LookMatcher.match(scene: sample, to: ReferenceProfile(sample: sample))
        #expect(abs(result.exposureStops) < 0.1)
        let out = Self.applied(result.adjustments, to: Self.scene)
        #expect(Fixture.meanDeltaE(out, Self.scene) < 1.5)
    }

    /// SC-002: example = preset applied to the scene; matching without knowing the preset gets close to it.
    @Test func recoversEveryPresetLookWithinDeltaE5() throws {
        let sceneSample = try #require(SceneSample(image: Self.cg(Self.scene)))
        for preset in try LookCatalog.bundled().looks {
            let example = Self.renderer.render(Self.scene, recipe: preset, strength: 1)
            let profile = ReferenceProfile(sample: try #require(SceneSample(image: Self.cg(example))))
            let result = LookMatcher.match(scene: sceneSample, to: profile)
            let dE = Fixture.meanDeltaE(Self.applied(result.adjustments, to: Self.scene), example)
            #expect(dE <= 5, "\(preset.id): mean ΔE2000 \(dE)")
        }
    }

    @Test func warmExampleOnAlreadyWarmSceneAddsLessWarmth() throws {
        var warm = LookAdjustments(); warm.temperature = 0.6
        let example = Self.applied(warm, to: Self.scene)
        let profile = ReferenceProfile(sample: try #require(SceneSample(image: Self.cg(example))))
        let neutralScene = try #require(SceneSample(image: Self.cg(Self.scene)))
        var halfWarm = LookAdjustments(); halfWarm.temperature = 0.4
        let warmScene = try #require(SceneSample(image: Self.cg(Self.applied(halfWarm, to: Self.scene))))
        let fromNeutral = LookMatcher.match(scene: neutralScene, to: profile).adjustments.temperature
        let fromWarm = LookMatcher.match(scene: warmScene, to: profile).adjustments.temperature
        #expect(fromNeutral > 0.3)
        // Matching prefers small changes, so it adds less than the full 0.6; what matters is that an
        // already warm scene gets clearly less (measured: 0.36 vs 0.17).
        #expect(fromWarm < fromNeutral * 0.6, "adapts to the scene instead of adding a fixed warmth")
    }

    @Test func blackAndWhiteExampleGivesBlackAndWhite() throws {
        var mono = LookAdjustments(); mono.saturation = -1
        let profile = ReferenceProfile(sample: try #require(SceneSample(image: Self.cg(Self.applied(mono, to: Self.scene)))))
        #expect(profile.isMonochrome)
        let result = LookMatcher.match(scene: try #require(SceneSample(image: Self.cg(Self.scene))), to: profile)
        #expect(result.adjustments.saturation <= -0.8)
    }

    @Test func brighterExampleAsksTheCameraForMoreLight() throws {
        var bright = LookAdjustments(); bright.exposure = 0.6
        let profile = ReferenceProfile(sample: try #require(SceneSample(image: Self.cg(Self.applied(bright, to: Self.scene)))))
        let result = LookMatcher.match(scene: try #require(SceneSample(image: Self.cg(Self.scene))), to: profile)
        #expect(result.exposureStops > 0.3)
    }

    @Test func vignetteDropConstantMatchesTheRenderer() throws {
        var v = LookAdjustments(); v.vignette = 1
        let plain = try #require(SceneSample(image: Self.cg(Self.scene)))
        let dark = try #require(SceneSample(image: Self.cg(Self.applied(v, to: Self.scene))))
        let drop = plain.cornerRatio - dark.cornerRatio
        #expect(abs(drop - LookMatcher.vignetteRatioDrop) < 0.08, "measured drop \(drop)")
    }

    @Test func deterministicAndFast() throws {
        let example = Self.renderer.render(Self.scene, recipe: try LookCatalog.bundled().looks[3], strength: 1)
        let clock = ContinuousClock()
        var results: [LookMatcher.Result] = []
        let elapsed = try clock.measure {
            for _ in 0..<2 {
                let profile = ReferenceProfile(sample: try #require(SceneSample(image: Self.cg(example))))
                results.append(LookMatcher.match(scene: try #require(SceneSample(image: Self.cg(Self.scene))), to: profile))
            }
        }
        #expect(results[0] == results[1])
        #expect(elapsed < .seconds(4), "two full runs: \(elapsed)") // SC-001: one run < 2 s
    }
}
