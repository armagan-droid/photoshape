import CoreGraphics
import CoreImage
import Foundation
import LookKit
import Testing
@testable import CompositionKit

@Suite("Example card content (spec 05 Hikâye 7, FR-011…FR-016, SC-010, SC-012)")
struct ReadingTests {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let context = CIContext(options: [.workingColorSpace: sRGB])

    /// Neutral scene (no color cast, mid brightness): gray table, white plate, food-like color patches.
    static func neutralScene() -> CGImage {
        let w = 400, h = 500
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), CGColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)] as CFArray
        ctx.drawLinearGradient(CGGradient(colorsSpace: sRGB, colors: colors, locations: [0, 1])!,
                               start: CGPoint(x: 0, y: h), end: .zero, options: [])
        ctx.setFillColor(CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 60, y: 120, width: 280, height: 280))
        // Red, green, yellow, blue food and napkin, balanced around neutral.
        let patches: [(CGRect, (Double, Double, Double))] = [
            (CGRect(x: 110, y: 180, width: 90, height: 90), (0.75, 0.22, 0.18)),
            (CGRect(x: 200, y: 180, width: 90, height: 90), (0.3, 0.6, 0.25)),
            (CGRect(x: 110, y: 270, width: 90, height: 80), (0.8, 0.68, 0.2)),
            (CGRect(x: 200, y: 270, width: 90, height: 80), (0.22, 0.35, 0.7)),
            (CGRect(x: 0, y: 0, width: 140, height: 90), (0.25, 0.4, 0.62)),
            (CGRect(x: 260, y: 410, width: 140, height: 90), (0.62, 0.3, 0.25)),
        ]
        for (rect, c) in patches {
            ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1))
            ctx.fill(rect)
        }
        return ctx.makeImage()!
    }

    static func profile(_ image: CGImage) throws -> ReferenceProfile {
        ReferenceProfile(sample: try #require(SceneSample(image: image)))
    }

    static func render(_ image: CGImage, _ recipe: LookRecipe) -> CGImage {
        let out = LookRenderer().render(CIImage(cgImage: image), recipe: recipe, strength: 1)
        return context.createCGImage(out, from: out.extent, format: .RGBA8, colorSpace: sRGB)!
    }

    static func reading(_ p: ReferenceProfile, subject: Subject? = nil, light: LightReading? = nil,
                        angle: ShotAngleEstimate? = nil) -> ExampleReading {
        ExampleReading(tone: p.stats, isMonochrome: p.isMonochrome, subject: subject, light: light, angle: angle)
    }

    static func keys(_ r: ExampleReading, _ topic: ExampleReading.Topic) -> [String] {
        r.lines.first { $0.topic == topic }?.phraseKeys ?? []
    }

    @Test func neutralSceneReadsNatural() throws {
        let r = Self.reading(try Self.profile(Self.neutralScene()))
        #expect(Self.keys(r, .color) == ["reading.color.natural"])
        #expect(Self.keys(r, .tone).first == "reading.tone.balanced")
    }

    /// SC-010: each preset look on the neutral scene reads as what the look is meant to be (5/5).
    @Test func presetLooksReadAsTheirDescription() throws {
        let scene = Self.neutralScene()
        let looks = Dictionary(uniqueKeysWithValues: try LookCatalog.bundled().looks.map { ($0.id, $0) })
        func read(_ id: String) throws -> ExampleReading {
            Self.reading(try Self.profile(Self.render(scene, try #require(looks[id]))))
        }
        let coffee = try read("coffee-break")
        #expect(Self.keys(coffee, .color).first?.hasPrefix("reading.color.warm") == true, "\(coffee)")
        let moody = try read("moody-table")
        #expect(Self.keys(moody, .tone).contains("reading.tone.dark") || Self.keys(moody, .tone).contains("reading.shadows.deep"), "\(moody)")
        let vivid = try read("vivid")
        #expect(Self.keys(vivid, .color).first?.hasSuffix("Vivid") == true, "\(vivid)")
        let film = try read("old-film")
        #expect(Self.keys(film, .color).first?.hasSuffix("Muted") == true || Self.keys(film, .tone).contains("reading.shadows.soft"), "\(film)")
        let morning = try read("morning-light")
        #expect(Self.keys(morning, .tone).contains("reading.tone.bright") || Self.keys(morning, .tone).contains("reading.shadows.soft"), "\(morning)")
    }

    @Test func coolLightReadsCoolAndFoodColorsDoNotMakeItWarm() throws {
        var cool = LookRecipe.natural
        cool.adjustments.temperature = -0.6
        #expect(Self.keys(Self.reading(try Self.profile(Self.render(Self.neutralScene(), cool))), .color).first?
            .hasPrefix("reading.color.cool") == true)
        // Orange food on a white plate under neutral light: the gray parts decide, not the food.
        var stats = try Self.profile(Self.neutralScene()).stats
        stats.meanB = 20
        #expect(ExampleReading.color(stats).hasPrefix("natural"))
    }

    @Test func blackAndWhiteSaysOnlyThat() throws {
        var mono = LookRecipe.natural
        mono.adjustments.saturation = -1
        let r = Self.reading(try Self.profile(Self.render(Self.neutralScene(), mono)))
        #expect(Self.keys(r, .color) == ["reading.color.mono"])
    }

    @Test func unreadableLinesAreLeftOutAndStepsFallBack() throws {
        let r = Self.reading(try Self.profile(Self.neutralScene()))
        #expect(!r.lines.contains { [.light, .angle, .subject].contains($0.topic) })
        #expect(r.steps == ["step.followOutline"])
        let unsure = Self.reading(try Self.profile(Self.neutralScene()), angle: ShotAngleEstimate(angle: .topDown, confidence: 0.2))
        #expect(!unsure.lines.contains { $0.topic == .angle })
    }

    @Test func stepsGoAngleThenFramingThenLightAndStopAtThree() throws {
        let subject = Subject(kind: .object, box: CGRect(x: 0.05, y: 0.1, width: 0.85, height: 0.8)) // fills, centered-left
        let light = LightReading(subjectToBackground: 1, sideBalance: -0.3, verticalBalance: 0, shadowDepth: 2.5, edgeSharpness: 0.4)
        let r = Self.reading(try Self.profile(Self.neutralScene()), subject: subject, light: light,
                             angle: ShotAngleEstimate(angle: .topDown, confidence: 0.9))
        #expect(r.steps == ["step.angle.topDown", "step.size.fills", "step.light.left"])
        #expect(Self.keys(r, .light) == ["reading.light.left", "reading.light.hard"])
        #expect(Self.keys(r, .angle) == ["reading.angle.topDown"])
        #expect(Self.keys(r, .subject) == ["reading.subject.object.fills", "reading.subject.at.center"])
    }

    @Test func subjectPositionAndPerson() throws {
        let left = Subject(kind: .person, box: CGRect(x: 0.1, y: 0.2, width: 0.25, height: 0.6))
        let r = Self.reading(try Self.profile(Self.neutralScene()), subject: left)
        #expect(Self.keys(r, .subject) == ["reading.subject.at.left"])
        #expect(r.steps == ["step.place.left"])
        let small = Subject(kind: .person, box: CGRect(x: 0.45, y: 0.6, width: 0.12, height: 0.3))
        #expect(Self.keys(Self.reading(try Self.profile(Self.neutralScene()), subject: small), .subject)
            == ["reading.subject.person.small", "reading.subject.at.lower"])
    }

    /// FR-016: a backlit example asks for light behind the subject, never "light beside you" (spec 04 FR-L3).
    @Test func backlitExampleKeepsTheLightBehind() throws {
        let backlit = LightReading(subjectToBackground: 0.35, sideBalance: 0.05, verticalBalance: 0)
        let r = Self.reading(try Self.profile(Self.neutralScene()), light: backlit)
        #expect(Self.keys(r, .light) == ["reading.light.back"])
        #expect(r.steps == ["step.light.back"])
    }

    /// The card's light step points the same way as the live advice for the same example (FR-013).
    @Test func cardAndLiveAdviceAgreeOnTheSide() throws {
        for side in [-0.3, 0.3] {
            let example = LightReading(subjectToBackground: 1, sideBalance: side)
            let r = Self.reading(try Self.profile(Self.neutralScene()), light: example)
            let live = CompositionGuide.lightDirection(.init(live: LightReading(subjectToBackground: 1, sideBalance: 0),
                                                             example: example, isDim: false))
            #expect(r.steps.first == "step.light.\(side < 0 ? "left" : "right")")
            #expect(live?.kind == "light.from\(side < 0 ? "Left" : "Right")")
        }
    }

    @Test func deterministic() throws {
        let p = try Self.profile(Self.neutralScene())
        let light = LightReading(subjectToBackground: 0.9, sideBalance: 0.2, verticalBalance: 0.1, shadowDepth: 1, edgeSharpness: 0.05)
        #expect(Self.reading(p, light: light) == Self.reading(p, light: light))
    }

    @Test func everyProducedKeyIsListed() throws {
        let all = Set(ExampleReading.allPhraseKeys)
        let subject = Subject(kind: .object, box: CGRect(x: 0.6, y: 0.1, width: 0.3, height: 0.3))
        let light = LightReading(subjectToBackground: 1, sideBalance: 0.3, shadowDepth: 1, edgeSharpness: 0.05)
        let r = Self.reading(try Self.profile(Self.neutralScene()), subject: subject, light: light,
                             angle: ShotAngleEstimate(angle: .angled, confidence: 1))
        for key in r.lines.flatMap(\.phraseKeys) + r.steps { #expect(all.contains(key), "\(key)") }
    }
}
