import CoreGraphics
import Foundation
import LookKit
import Testing
@testable import CompositionKit

@Suite("Example summary: input and check (spec 05 Hikâye 9, FR-025…FR-027, SC-018, SC-019)")
struct SummaryTests {
    /// Left soft light, warm vivid, top-down, object filling the frame in the middle, bright.
    static let facts = ["light.left", "light.soft", "tone.bright", "shadows.soft", "color.warmVivid",
                        "angle.topDown", "subject.object.fills", "subject.at.center"]
    static let tr = ExampleSummaryInput(language: "tr", facts: facts)
    static let en = ExampleSummaryInput(language: "en", facts: facts)

    // MARK: - SC-018: input

    static func reading(light: LightReading?, angle: ShotAngleEstimate?) -> ExampleReading {
        // Mid gray everywhere: a balanced, natural reading.
        let stats = ColorStats(colors: Array(repeating: SIMD3(0.47, 0.47, 0.47), count: 400))
        return ExampleReading(tone: stats, isMonochrome: false,
                              subject: Subject(kind: .object, box: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)),
                              light: light, angle: angle)
    }

    @Test func inputIsDeterministicAndOnlyHasShownLines() {
        let r = Self.reading(light: nil, angle: nil)
        let a = ExampleSummaryInput(reading: r, language: "tr"), b = ExampleSummaryInput(reading: r, language: "tr")
        #expect(a == b)
        #expect(a.prompt == b.prompt && a.instructions == b.instructions)
        // No light and no angle line on the card: nothing about them in the input (Hikâye 9.4).
        #expect(!a.facts.contains { $0.hasPrefix("light.") || $0.hasPrefix("angle.") })
        #expect(a.facts.contains("tone.balanced"))
        #expect(a.facts.allSatisfy { ExampleSummaryInput.describe($0) != nil })
    }

    @Test func everyCardKeyHasADescription() {
        let readingKeys = ExampleReading.allPhraseKeys.filter { $0.hasPrefix("reading.") }
        let missing = readingKeys.filter { ExampleSummaryInput.describe(String($0.dropFirst("reading.".count))) == nil }
        #expect(missing == [])
    }

    @Test func promptHasNoNumbersAndNamesTheLanguage() {
        let hasDigit = Self.tr.prompt.contains { $0.isNumber }
        #expect(!hasDigit)
        #expect(Self.tr.instructions.contains("Turkish") && Self.en.instructions.contains("English"))
    }

    // MARK: - SC-019: the check, on hand-written summaries

    static let goodTurkish = [
        "Işık soldan ve yumuşak geliyor, gölgeler hafif. Tepeden çekilmiş, konu kareyi dolduruyor. Renkler sıcak ve canlı.",
        "Fotoğraf aydınlık; ışık soldan yumuşakça vuruyor. Konu ortada ve kareyi dolduruyor.",
        "Tepeden çekilmiş bu karede renkler sıcak ve canlı. Yumuşak ışık soldan geliyor.",
        "Konu kareyi dolduruyor ve ortada duruyor. Işık soldan geldiği için gölgeler yumuşak.",
        "Aydınlık bir fotoğraf. Sıcak ve canlı renkler, soldan gelen yumuşak bir ışık var.",
    ]
    static let goodEnglish = [
        "Soft light comes from the left, so the shadows are gentle. It was shot from above and the subject fills the frame.",
        "A bright photo with warm, vivid colors. The light is soft and comes from the left.",
        "Shot top down, with the subject in the middle filling the frame. Warm, vivid colors and soft light.",
        "The subject fills the frame. Soft light from the left keeps it bright and the colors warm.",
        "Bright and warm. The light falls softly from the left onto the subject in the middle.",
    ]

    @Test(arguments: goodTurkish)
    func acceptsCorrectTurkish(text: String) {
        #expect(SummaryChecker.problems(text, input: Self.tr) == [])
    }

    @Test(arguments: goodEnglish)
    func acceptsCorrectEnglish(text: String) {
        #expect(SummaryChecker.problems(text, input: Self.en) == [])
    }

    static let badTurkish: [(String, SummaryChecker.Problem)] = [
        ("Işık sağdan ve yumuşak geliyor. Renkler sıcak.", .unsupported("sağdan")),
        ("Işık soldan geliyor ama renkler soğuk.", .unsupported("soğuk")),
        ("Göz hizasından çekilmiş, konu ortada.", .unsupported("göz hizasından")),
        ("Karanlık bir fotoğraf, ışık soldan.", .unsupported("karanlık")),
        ("Işık sert ve soldan geliyor.", .unsupported("sert")),
        ("Renkler soluk, ışık soldan.", .unsupported("soluk")),
        ("Siyah beyaz bir kare, ışık soldan.", .unsupported("siyah beyaz")),
        ("Konu ters ışıkta duruyor.", .unsupported("ters ışıkta")),
        ("Fincan kareyi dolduruyor, ışık soldan.", .namesSubject("fincan")),
        ("Kahvenin üstüne ışık soldan düşüyor.", .namesSubject("kahve")),
        ("Işık soldan geliyor ve enstantane 1/125 sn.", .hasDigits),
        ("Soft light comes from the left and the colors are warm.", .wrongLanguage),
        ("Işık soldan geliyor. Renkler sıcak. Konu ortada. Tepeden çekilmiş.", .tooManySentences),
        ("", .empty),
        // Seen from the real model (2026-11-24): an angle the reading never gives.
        ("Konu ortada, aşağıdan bakılarak çekilmiş.", .unsupported("aşağıdan")),
        // Seen from the real model: "from the right" for a subject on the right while the light is frontal.
        ("Işık önden, fotoğrafçıdan sağdan gelir.", .unsupported("sağdan")),
    ]

    static let badEnglish: [(String, SummaryChecker.Problem)] = [
        ("Soft light comes from the right.", .unsupported("right")),
        ("Hard light from the left gives sharp shadows.", .unsupported("hard")),
        ("A dark, moody photo with light from the left.", .unsupported("dark")),
        ("Shot at eye level with soft light from the left.", .unsupported("eye level")),
        ("Cool colors and soft light from the left.", .unsupported("cool")),
        ("The cup fills the frame with soft light from the left.", .namesSubject("cup")),
        ("A plate of food lit softly from the left.", .namesSubject("plate")),
        ("Taken at ISO 64 with soft light from the left.", .hasDigits),
        ("Shot from below with soft light from the left.", .unsupported("from below")),
        ("Işık soldan ve yumuşak geliyor, renkler sıcak ve canlı.", .wrongLanguage),
        (String(repeating: "The soft light from the left is warm and bright and ", count: 5) + "gentle.", .tooLong),
    ]

    @Test(arguments: badTurkish.indices)
    func rejectsWrongTurkish(index: Int) {
        let (text, problem) = Self.badTurkish[index]
        #expect(SummaryChecker.problems(text, input: Self.tr).contains(problem), "\(text)")
    }

    @Test(arguments: badEnglish.indices)
    func rejectsWrongEnglish(index: Int) {
        let (text, problem) = Self.badEnglish[index]
        #expect(SummaryChecker.problems(text, input: Self.en).contains(problem), "\(text)")
    }

    @Test func atLeastThirtyHandWrittenCases() {
        #expect(Self.goodTurkish.count + Self.goodEnglish.count + Self.badTurkish.count + Self.badEnglish.count >= 30)
    }

    @Test func placeWordsDoNotLicenseLightDirection() {
        let tr = ExampleSummaryInput(language: "tr", facts: ["light.front", "subject.at.right", "tone.bright"])
        #expect(SummaryChecker.problems("Konu sağda duruyor, ışık önden geliyor.", input: tr) == [])
        #expect(SummaryChecker.problems("Konu sağda, ışık sağdan geliyor.", input: tr).contains(.unsupported("sağdan")))
        let en = ExampleSummaryInput(language: "en", facts: ["light.front", "subject.at.right", "tone.bright"])
        #expect(SummaryChecker.problems("The subject is on the right, lit from the front.", input: en) == [])
        #expect(SummaryChecker.problems("Light comes from the right.", input: en).contains(.unsupported("from the right")))
    }

    /// A hidden line cannot be talked about: with no light facts, any light direction is rejected.
    @Test func hiddenLineCannotBeMentioned() {
        let input = ExampleSummaryInput(language: "tr", facts: ["tone.bright", "color.warmVivid"])
        #expect(SummaryChecker.problems("Aydınlık ve sıcak renkli bir kare.", input: input) == [])
        #expect(SummaryChecker.problems("Aydınlık bir kare, ışık soldan geliyor.", input: input).contains(.unsupported("soldan")))
    }

    @Test func lookAlikeWordsAreNotSubjects() {
        let input = ExampleSummaryInput(language: "tr", facts: ["color.warmMuted", "tone.balanced"])
        #expect(SummaryChecker.problems("Sıcak, kahverengi tonlarda soluk renkler var.", input: input) == [])
        let en = ExampleSummaryInput(language: "en", facts: ["color.warmMuted", "tone.balanced"])
        #expect(SummaryChecker.problems("Many warm but muted tones fill this photo.", input: en) == [])
    }
}
