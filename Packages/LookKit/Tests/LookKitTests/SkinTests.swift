import CoreImage
import Foundation
import Testing
@testable import LookKit

@Suite("Skin left out of the example's colors (spec 05 FR-004, Hikâye 4, SC-004)")
struct SkinTests {
    @Test(arguments: [SIMD3(0.94, 0.78, 0.70), SIMD3(0.80, 0.58, 0.45), SIMD3(0.55, 0.38, 0.28), SIMD3(0.36, 0.24, 0.18)])
    func skinTonesAreSkinColored(c: SIMD3<Double>) {
        #expect(SkinTone.isSkinColor(c))
    }

    @Test(arguments: [SIMD3(0.5, 0.5, 0.5), SIMD3(0.2, 0.4, 0.8), SIMD3(0.3, 0.7, 0.3), SIMD3(0.05, 0.04, 0.03), SIMD3(0.98, 0.98, 0.98)])
    func otherColorsAreNot(c: SIMD3<Double>) {
        #expect(!SkinTone.isSkinColor(c))
    }

    /// 32 × 40 grid: neutral café table, a person whose face and arms (skin) fill the middle, a latte at the bottom
    /// that is skin-colored but outside the person.
    static func portrait() -> (SceneSample, [Float]) {
        let w = SceneSample.gridWidth, h = SceneSample.gridHeight
        var colors: [SIMD3<Double>] = [], mask: [Float] = []
        for y in 0..<h {
            for x in 0..<w {
                let inPerson = (6..<26).contains(x) && (4..<30).contains(y)
                let latte = (12..<20).contains(x) && (33..<39).contains(y)
                let shirt = inPerson && y >= 22
                colors.append(inPerson ? (shirt ? SIMD3(0.45, 0.47, 0.50) : SIMD3(0.88, 0.64, 0.50))
                              : latte ? SIMD3(0.78, 0.62, 0.47) : SIMD3(0.55, 0.55, 0.54))
                mask.append(inPerson ? 1 : 0)
            }
        }
        return (SceneSample(colors: colors, cornerRatio: 1), mask)
    }

    @Test func onlySkinInsideThePersonIsLeftOut() {
        let (sample, mask) = Self.portrait()
        let skin = SkinTone.skinCells(colors: sample.colors, personMask: mask)
        let w = SceneSample.gridWidth
        #expect(skin[10 * w + 15], "face")
        #expect(!skin[25 * w + 15], "shirt is inside the person but not skin")
        #expect(!skin[35 * w + 15], "latte is skin-colored but not a person")
    }

    /// SC-004 (synthetic): matching a neutral café scene to the portrait gives clearly less warmth when skin is left out.
    @Test func portraitDoesNotTurnTheSceneOrange() {
        let (sample, mask) = Self.portrait()
        let with = ReferenceProfile(sample: sample)
        let without = ReferenceProfile(sample: sample, excluding: SkinTone.skinCells(colors: sample.colors, personMask: mask))
        #expect(without.stats.meanB < with.stats.meanB - 5)
        let cafe = SceneSample(colors: Array(repeating: SIMD3(0.55, 0.55, 0.54), count: sample.colors.count), cornerRatio: 1)
        let warmWith = LookMatcher.match(scene: cafe, to: with).adjustments.temperature
        let warmWithout = LookMatcher.match(scene: cafe, to: without).adjustments.temperature
        #expect(warmWithout < warmWith - 0.1, "with skin \(warmWith), without \(warmWithout)")
    }

    @Test func tooLittleLeftMeansNothingIsLeftOut() {
        let colors = Array(repeating: SIMD3(0.88, 0.64, 0.50), count: 100)
        let all = Array(repeating: true, count: 100)
        #expect(ReferenceProfile(sample: SceneSample(colors: colors, cornerRatio: 1), excluding: all)
                == ReferenceProfile(sample: SceneSample(colors: colors, cornerRatio: 1)))
    }
}


@Suite("White balance gains before the look (spec 02 Hikâye 3.2, FR-005)")
struct ChannelGainsTests {
    /// The renderer (preview and saved photo) and the brain's estimate agree.
    @Test func rendererMatchesTheEstimate() throws {
        let gains = ChannelGains(coolingRatio: 1.6)
        let color = SIMD3(0.86, 0.78, 0.55)
        let image = CIImage(color: CIColor(red: color.x, green: color.y, blue: color.z, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let out = LookRenderer().render(image, recipe: try LookCatalog.bundled().looks[0], strength: 0, gains: gains)
        var px = [UInt8](repeating: 0, count: 4)
        CIContext().render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let rendered = ColorScience.lab(fromSRGB: (Double(px[0]) / 255, Double(px[1]) / 255, Double(px[2]) / 255))
        let e = gains.apply(color)
        let estimated = ColorScience.lab(fromSRGB: (e.x, e.y, e.z))
        #expect(ColorScience.deltaE2000(rendered, estimated) < 1.5)
        #expect(rendered.b < ColorScience.lab(fromSRGB: (color.x, color.y, color.z)).b - 5)
    }

    @Test func neutralGainsChangeNothing() {
        let c = SIMD3(0.3, 0.6, 0.9)
        let out = ChannelGains.neutral.apply(c)
        #expect(abs(out.x - c.x) < 1e-9 && abs(out.y - c.y) < 1e-9 && abs(out.z - c.z) < 1e-9)
    }
}
