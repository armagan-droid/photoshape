import CoreGraphics
import Foundation
import LookKit
import Testing
@testable import CompositionKit

@Suite("White balance keeps some warmth (spec 02 FR-003, Hikâye 3, SC-003)")
struct WhiteBalanceTests {
    @Test(arguments: [nil, 0, 5000, 5500, 6500, 7500, 10000] as [Double?])
    func daylightAndCoolLightAreFullyNeutral(kelvin: Double?) {
        #expect(WhiteBalanceDecider.warmth(cameraKelvin: kelvin) == 0)
    }

    @Test func warmerLightKeepsMoreWarmthWithinLimits() {
        let values = [4800.0, 4500, 4000, 3500, 3000, 2700, 2200].map { WhiteBalanceDecider.warmth(cameraKelvin: $0) }
        for (a, b) in zip(values, values.dropFirst()) { #expect(b >= a) }
        #expect(values[0] > 0)
        // Graded where light is only a little warm, not a switch.
        #expect(values[0] < values[1] && values[1] < values[2])
        #expect(values.allSatisfy { $0 <= WhiteBalanceDecider.maxWarmth })
        // A lamp at 2700 K stays visibly warm, but far from orange.
        #expect(values[5] > 0.2)
    }

    /// Hikâye uç durum "hızlı ışık değişimi": no jump at the edge where warmth starts.
    @Test func startsSmoothly() {
        let a = WhiteBalanceDecider.warmth(cameraKelvin: 4990), b = WhiteBalanceDecider.warmth(cameraKelvin: 5010)
        #expect(a < 0.02 && b == 0)
    }

    @Test func blackbodyRedBlueRisesAsLightWarms() {
        #expect(WhiteBalanceDecider.redBlueRatio(2700) > WhiteBalanceDecider.redBlueRatio(4000))
        #expect(WhiteBalanceDecider.redBlueRatio(4000) > WhiteBalanceDecider.redBlueRatio(6504))
        // Daylight is close to sRGB white.
        #expect(abs(WhiteBalanceDecider.redBlueRatio(6504) - 1) < 0.1)
    }

    /// SC-003, synthetic part: a white plate under a warm lamp. The camera neutralizes it; the app gives some back.
    /// The cast is at least halved compared with no correction, and never fully removed.
    @Test(arguments: [2700.0, 3000, 3500, 4000])
    func castIsMoreThanHalvedButNotZero(kelvin: Double) {
        let uncorrectedCast = log(WhiteBalanceDecider.redBlueRatio(kelvin) / WhiteBalanceDecider.redBlueRatio(6504))
        var look = LookAdjustments()
        look.temperature = WhiteBalanceDecider.warmth(cameraKelvin: kelvin)
        let (r, _, b) = ColorTransform(look).apply(0.8, 0.8, 0.8)
        let cast = log(linear(r) / linear(b))
        #expect(cast > 0)
        #expect(cast <= 0.5 * uncorrectedCast)
    }

    func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
}

@Suite("Mixed light: white balance follows the subject (spec 02 Hikâye 3.2)")
struct MixedLightTests {
    /// 32 × 40 frame: a white plate in the middle (the subject) and white walls around, each with its own cast.
    static func frame(plate: SIMD3<Double>, walls: SIMD3<Double>) -> [SIMD3<Double>] {
        (0..<40).flatMap { y in (0..<32).map { x in
            (10..<22).contains(x) && (14..<26).contains(y) ? plate : walls
        } }
    }
    static let box = CGRect(x: 10.0 / 32, y: 14.0 / 40, width: 12.0 / 32, height: 12.0 / 40)
    static let yellow = SIMD3(0.86, 0.78, 0.55), white = SIMD3(0.80, 0.80, 0.80), blue = SIMD3(0.70, 0.76, 0.88)

    @Test func lampOnTheSubjectWindowAroundIsMixed() throws {
        let m = try #require(WhiteBalanceDecider.mixedLight(colors: Self.frame(plate: Self.yellow, walls: Self.blue), width: 32, height: 40, subject: Self.box))
        #expect(m.isMixed && m.subjectCast > m.surroundCast)
        // The gains cool the subject, but not all the way to neutral.
        let g = WhiteBalanceDecider.gains(for: m)
        #expect(g.blue > g.red)
        let c = g.apply(Self.yellow)
        let after = ColorScience.lab(fromSRGB: (c.x, c.y, c.z)).b
        #expect(after < m.subjectCast * 0.5 && after > 0, "subject cast \(m.subjectCast) → \(after)")
    }

    @Test func oneLightIsNotMixed() throws {
        let m = try #require(WhiteBalanceDecider.mixedLight(colors: Self.frame(plate: Self.yellow, walls: Self.yellow), width: 32, height: 40, subject: Self.box))
        #expect(!m.isMixed)
        #expect(WhiteBalanceDecider.gains(for: m) == .neutral)
    }

    @Test func noGraySurfacesMeansNoReading() {
        let red = SIMD3(0.8, 0.1, 0.1)
        #expect(WhiteBalanceDecider.mixedLight(colors: Self.frame(plate: red, walls: red), width: 32, height: 40, subject: Self.box) == nil)
    }

    @Test func coolWindowOnTheSubjectWarmsIt() throws {
        let m = try #require(WhiteBalanceDecider.mixedLight(colors: Self.frame(plate: Self.blue, walls: Self.yellow), width: 32, height: 40, subject: Self.box))
        #expect(m.isMixed)
        let g = WhiteBalanceDecider.gains(for: m)
        #expect(g.red > g.blue)
    }
}
