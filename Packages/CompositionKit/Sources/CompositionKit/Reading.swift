import CoreGraphics
import Foundation
import LookKit

/// "How was this shot?": the content of the example card (spec 05 Hikâye 7, FR-011). Pure and deterministic.
/// Every line and step is a phrase key from the String Catalog; the screen only shows what is here.
/// A line the app cannot read is left out, never shown as unknown (Hikâye 7.3).
public struct ExampleReading: Sendable, Hashable {
    public enum Topic: String, Sendable, Hashable, CaseIterable { case light, tone, color, angle, subject }

    public struct Line: Sendable, Hashable {
        public var topic: Topic
        /// Short sentences shown one after the other.
        public var phraseKeys: [String]
    }

    public var lines: [Line]
    /// "Böyle çek": at most three, most important first (angle and framing, then light).
    public var steps: [String]

    public static let maxSteps = 3

    public init(tone: ColorStats, isMonochrome: Bool, subject: Subject?, light: LightReading?, angle: ShotAngleEstimate?) {
        let shotAngle = angle.flatMap { $0.confidence >= ShotAngleEstimator.minimumConfidence ? $0.angle : nil }
        let source = light.flatMap { LightCharacter.source($0, angle: shotAngle) }
        let quality = light.flatMap(LightCharacter.quality)
        var lines: [Line] = []
        var steps: [String] = []

        // Light
        var lightKeys: [String] = []
        if let source { lightKeys.append("reading.light.\(source.rawValue)") }
        if let quality { lightKeys.append("reading.light.\(quality.rawValue)") }
        if !lightKeys.isEmpty { lines.append(Line(topic: .light, phraseKeys: lightKeys)) }

        // Tone
        var toneKeys = ["reading.tone.\(Self.brightness(tone))"]
        if let shadows = Self.shadows(tone) { toneKeys.append("reading.shadows.\(shadows)") }
        lines.append(Line(topic: .tone, phraseKeys: toneKeys))

        // Color
        lines.append(Line(topic: .color, phraseKeys: [isMonochrome ? "reading.color.mono" : "reading.color.\(Self.color(tone))"]))

        // Angle
        if let shotAngle {
            lines.append(Line(topic: .angle, phraseKeys: ["reading.angle.\(shotAngle.rawValue)"]))
            steps.append("step.angle.\(shotAngle.rawValue)")
        }

        // Subject
        if let subject, let place = Self.place(subject.box) {
            let who = subject.kind == .person ? "person" : "object"
            var keys: [String] = []
            if let size = place.size { keys.append("reading.subject.\(who).\(size)") }
            keys.append("reading.subject.at.\(place.position)")
            lines.append(Line(topic: .subject, phraseKeys: keys))
            if let size = place.size { steps.append("step.size.\(size)") }
            if place.position != "center" || place.size == nil { steps.append("step.place.\(place.position)") }
        }

        // Light advice is advice only (Constitution III) and points the same way as the live advice (FR-016).
        if let source { steps.append("step.light.\(source.rawValue)") }
        if let quality { steps.append("step.light.\(quality.rawValue)") }

        if steps.isEmpty { steps.append("step.followOutline") }
        self.lines = lines
        self.steps = Array(steps.prefix(Self.maxSteps))
    }

    // MARK: - Decisions (initial thresholds; tuned on the test set, plan "Eşikler")

    static func brightness(_ t: ColorStats) -> String {
        t.meanL > 60 ? "bright" : t.meanL < 40 ? "dark" : "balanced"
    }

    static func shadows(_ t: ColorStats) -> String? {
        t.lowL < 12 ? "deep" : t.lowL > 30 ? "soft" : nil
    }

    static func color(_ t: ColorStats) -> String {
        // The cast of the light, read from the gray parts; the whole picture's mean only when there are none.
        let warmth: String
        if let b = t.neutralB { warmth = b > 2 ? "warm" : b < -2 ? "cool" : "natural" }
        else { warmth = t.meanB > 9 ? "warm" : t.meanB < -3 ? "cool" : "natural" }
        let vividness = t.meanChroma > 18 ? "Vivid" : t.meanChroma < 10.5 ? "Muted" : ""
        return warmth + vividness
    }

    /// Size and position of the subject in the example (normalized box, origin top-left).
    static func place(_ box: CGRect) -> (size: String?, position: String)? {
        let b = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !b.isNull, b.width > 0.02, b.height > 0.02 else { return nil }
        let area = Double(b.width * b.height)
        let size: String? = area > 0.4 ? "fills" : area < 0.08 ? "small" : nil
        let dx = Double(b.midX) - 0.5, dy = Double(b.midY) - 0.5
        let position: String
        if abs(dx) >= 0.12 { position = dx < 0 ? "left" : "right" }
        else if abs(dy) >= 0.15 { position = dy < 0 ? "upper" : "lower" }
        else { position = "center" }
        return (size, position)
    }

    // MARK: - Every key the card can show (SC-011 checks them against the String Catalog)

    public static var allPhraseKeys: [String] {
        let warmth = ["warm", "cool", "natural"], vivid = ["", "Vivid", "Muted"]
        let positions = ["left", "right", "upper", "lower", "center"]
        return LightSource.allCases.map { "reading.light.\($0.rawValue)" }
            + LightQuality.allCases.map { "reading.light.\($0.rawValue)" }
            + ["bright", "dark", "balanced"].map { "reading.tone.\($0)" }
            + ["deep", "soft"].map { "reading.shadows.\($0)" }
            + ["reading.color.mono"] + warmth.flatMap { w in vivid.map { "reading.color.\(w)\($0)" } }
            + ShotAngle.allCases.map { "reading.angle.\($0.rawValue)" }
            + ["person", "object"].flatMap { who in ["fills", "small"].map { "reading.subject.\(who).\($0)" } }
            + positions.map { "reading.subject.at.\($0)" }
            + stepKeys
    }

    public static var stepKeys: [String] {
        ShotAngle.allCases.map { "step.angle.\($0.rawValue)" }
            + ["fills", "small"].map { "step.size.\($0)" }
            + ["left", "right", "upper", "lower", "center"].map { "step.place.\($0)" }
            + LightSource.allCases.map { "step.light.\($0.rawValue)" }
            + LightQuality.allCases.map { "step.light.\($0.rawValue)" }
            + ["step.followOutline"]
    }

    public static var topicTitleKeys: [String] { Topic.allCases.map { "reading.topic.\($0.rawValue)" } }
}
