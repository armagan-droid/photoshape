import Testing
@testable import FrameKit

@Suite("Guidance stabilizer (spec 04 FR-008, SC-004, SC-K2)")
struct GuidanceTests {
    static let closer = GuidanceInstruction(kind: "frame.closer", direction: .closer, priority: 1, phraseKey: "guide.closer")
    static let left = GuidanceInstruction(kind: "frame.panLeft", direction: .left, priority: 2, phraseKey: "guide.panLeft")

    @Test func showsAnInstructionOnceItSettles() {
        var s = GuidanceStabilizer()
        #expect(s.update(candidate: Self.closer, at: 0) == nil)
        #expect(s.update(candidate: Self.closer, at: 0.2) == nil)
        #expect(s.update(candidate: Self.closer, at: 0.4) == Self.closer)
    }

    @Test func noFlickerWhenTheSceneHoversAtAThreshold() {
        var s = GuidanceStabilizer()
        var changes: [Double] = []
        var last: GuidanceInstruction?
        var t = 0.0
        while t < 20 {
            // Raw signal flips every 0.1 s between "closer" and "ready".
            let raw = Int(t * 10) % 2 == 0 ? Self.closer : nil
            let shown = s.update(candidate: raw, at: t)
            if shown != last { changes.append(t); last = shown }
            t += 1.0 / 30
        }
        let gaps = zip(changes.dropFirst(), changes).map { $0 - $1 }
        #expect(gaps.allSatisfy { $0 >= 1.0 - 1e-9 }, "changes at \(changes)")
    }

    @Test func keepsAnInstructionAtLeastOneSecond() {
        var s = GuidanceStabilizer()
        for t in stride(from: 0.0, through: 0.4, by: 0.1) { s.update(candidate: Self.closer, at: t) }
        #expect(s.shown == Self.closer)
        for t in stride(from: 0.5, through: 1.3, by: 0.1) { #expect(s.update(candidate: Self.left, at: t) == Self.closer) }
        #expect(s.update(candidate: Self.left, at: 1.45) == Self.left)
    }

    @Test func stopsNaggingAndStaysQuiet() {
        var s = GuidanceStabilizer()
        var t = 0.0
        while t < 8.5 { s.update(candidate: Self.closer, at: t); t += 0.1 }
        #expect(s.shown == nil, "hidden after the nag limit")
        while t < 25 { #expect(s.update(candidate: Self.closer, at: t) != Self.closer); t += 0.5 }
        // Other instructions still come through during the quiet period.
        for dt in stride(from: 0.0, through: 0.5, by: 0.1) { s.update(candidate: Self.left, at: t + dt) }
        #expect(s.shown == Self.left)
    }
}
