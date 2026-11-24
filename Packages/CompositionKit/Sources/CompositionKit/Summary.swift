import Foundation
import NaturalLanguage

/// What the on-device language model may say about the example (spec 05 Hikâye 9, FR-025, Constitution 2.1.0 IV).
/// Built only from the lines the card shows, so a hidden line can never reach the summary. Pure and deterministic.
public struct ExampleSummaryInput: Codable, Sendable, Hashable {
    /// "tr" or "en".
    public var language: String
    /// Card facts as "topic.value" (e.g. "light.left", "color.warmVivid", "subject.person.fills"), in card order.
    public var facts: [String]

    public init(language: String, facts: [String]) {
        self.language = language
        self.facts = facts
    }

    /// From the card's reading: each shown phrase key becomes one fact.
    public init(reading: ExampleReading, language: String) {
        let prefix = "reading."
        let facts = reading.lines.flatMap(\.phraseKeys).compactMap { $0.hasPrefix(prefix) ? String($0.dropFirst(prefix.count)) : nil }
        self.init(language: language == "tr" ? "tr" : "en", facts: facts)
    }

    public var isEmpty: Bool { facts.isEmpty }

    /// The model's instructions (FR-031: built in, not shown to the user). English works best with the
    /// system model; the answer language is asked for explicitly.
    public var instructions: String {
        """
        You describe how a photo was taken, for someone who knows nothing about photography.
        Use only the facts you are given. Never add anything that is not in the facts.
        Rules:
        - Write in \(languageName). Write two or three sentences, never more; join related facts in one sentence. At most \(SummaryChecker.maxWords) words in total.
        - Mention where the subject is, or left and right, only when a fact says so.
        - No numbers or digits. No technical settings.
        - Do not name what the subject is (no cup, coffee, food, plate, flower). Say "the subject"\(language == "tr" ? " (\"konu\")" : "") or, if a fact says person, "the person"\(language == "tr" ? " (\"kişi\")" : "").
        - Do not tell the reader what to do. Describe the photo.
        - Left and right are as seen by the photographer.
        - Answer with the description only.
        """
    }

    /// The facts in plain English, one per line.
    public var prompt: String {
        "Facts about the photo:\n" + facts.map { "- " + (Self.describe($0) ?? $0) }.joined(separator: "\n")
    }

    var languageName: String { language == "tr" ? "Turkish" : "English" }

    static func describe(_ fact: String) -> String? {
        switch fact {
        case "light.left": "Light comes from the left."
        case "light.right": "Light comes from the right."
        case "light.front": "Light comes from the front, from the photographer's side."
        case "light.back": "Light comes from behind the subject (backlight)."
        case "light.top": "Light comes from above."
        case "light.soft": "The light is soft; shadow edges are gentle."
        case "light.hard": "The light is hard; shadow edges are sharp."
        case "tone.bright": "The photo is bright overall."
        case "tone.dark": "The photo is dark overall."
        case "tone.balanced": "The brightness is balanced, neither bright nor dark."
        case "shadows.deep": "Shadows are deep."
        case "shadows.soft": "Shadows are light and open."
        case "color.mono": "The photo is black and white."
        case "angle.topDown": "Shot from directly above (top-down)."
        case "angle.angled": "Shot from an angle, looking down a little."
        case "angle.eyeLevel": "Shot at eye level."
        case "subject.person.fills", "subject.object.fills": "The \(subjectWord(fact)) fills most of the frame."
        case "subject.person.small", "subject.object.small": "The \(subjectWord(fact)) is small in the frame."
        case let f where f.hasPrefix("color."):
            colorDescription(String(f.dropFirst("color.".count)))
        case let f where f.hasPrefix("subject.at."):
            placeDescription(String(f.dropFirst("subject.at.".count)))
        default: nil
        }
    }

    static func subjectWord(_ fact: String) -> String { fact.hasPrefix("subject.person") ? "person" : "subject" }

    static func colorDescription(_ v: String) -> String {
        let warmth = v.hasPrefix("warm") ? "warm" : v.hasPrefix("cool") ? "cool" : "natural"
        let vivid = v.hasSuffix("Vivid") ? " and vivid" : v.hasSuffix("Muted") ? " and muted" : ""
        return "Colors are \(warmth)\(vivid)."
    }

    static func placeDescription(_ v: String) -> String {
        switch v {
        case "center": "The subject is in the middle of the frame."
        case "upper": "The subject is in the upper part of the frame."
        case "lower": "The subject is in the lower part of the frame."
        default: "The subject is on the \(v) side of the frame."
        }
    }
}

/// Checks a generated summary before it is shown (spec 05 FR-026, FR-027). Deterministic, no model needed.
/// A word that describes light, color, tone, angle or place is only allowed when a fact supports it, so the
/// summary can neither contradict the card nor talk about a line the card hid.
public enum SummaryChecker {
    public static let maxWords = 45
    public static let maxSentences = 3

    public enum Problem: Sendable, Hashable {
        case empty
        case tooLong
        case tooManySentences
        case wrongLanguage
        case hasDigits
        /// A word no fact supports, e.g. "sağdan" when the light comes from the left.
        case unsupported(String)
        /// Names what the subject is (cup, food, person…) although the reading does not know it.
        case namesSubject(String)
    }

    public static func problems(_ text: String, input: ExampleSummaryInput) -> [Problem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [.empty] }
        var out: [Problem] = []
        let words = tokens(trimmed, language: input.language)
        if words.count > maxWords { out.append(.tooLong) }
        if sentenceCount(trimmed) > maxSentences { out.append(.tooManySentences) }
        if trimmed.contains(where: \.isNumber) { out.append(.hasDigits) }
        if !isLanguage(trimmed, input.language) { out.append(.wrongLanguage) }

        let facts = Set(input.facts)
        let lexicon = input.language == "tr" ? Lexicon.turkish : Lexicon.english
        for (phrase, supporters) in lexicon where contains(words, phrase) {
            if !supporters.contains(where: { s in facts.contains { $0 == s || $0.hasPrefix(s) } }) {
                out.append(.unsupported(phrase.joined(separator: " ")))
            }
        }
        for noun in Lexicon.namedSubjects(in: words, language: input.language) { out.append(.namesSubject(noun)) }
        return out
    }

    public static func isAcceptable(_ text: String, input: ExampleSummaryInput) -> Bool {
        problems(text, input: input).isEmpty
    }

    // MARK: - Text helpers

    static func tokens(_ text: String, language: String) -> [String] {
        let lower = text.lowercased(with: Locale(identifier: language == "tr" ? "tr_TR" : "en_US"))
        return lower.split { !($0.isLetter || $0 == "'" || $0 == "’") }.map(String.init)
    }

    static func sentenceCount(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).count
    }

    static func isLanguage(_ text: String, _ language: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.turkish, .english]
        recognizer.processString(text)
        let expected: NLLanguage = language == "tr" ? .turkish : .english
        return recognizer.dominantLanguage == expected
    }

    static func contains(_ words: [String], _ phrase: [String]) -> Bool {
        guard !phrase.isEmpty, words.count >= phrase.count else { return false }
        for i in 0...(words.count - phrase.count) where Array(words[i..<(i + phrase.count)]) == phrase { return true }
        return false
    }

    /// Word (or phrase) → facts any one of which allows it. A supporter ending in "." matches by prefix
    /// ("color.warm" covers "color.warmVivid").
    enum Lexicon {
        static func entries(_ list: [([String], [String])]) -> [([String], [String])] {
            list.flatMap { words, supporters in words.map { ($0.split(separator: " ").map(String.init), supporters) } }
        }

        static let left = ["light.left", "subject.at.left"], right = ["light.right", "subject.at.right"]
        static let soft = ["light.soft", "shadows.soft"], dark = ["tone.dark", "shadows.deep"]

        static let turkish = entries([
            // "-dan/-den" says where light comes from, never where the subject is.
            (["soldan", "solundan", "sol taraftan"], ["light.left"]),
            (["sağdan", "sağından", "sağ taraftan"], ["light.right"]),
            (["sol", "solda", "sola", "soluna", "solunda", "soldaki"], left),
            (["sağ", "sağda", "sağa", "sağına", "sağında", "sağdaki"], right),
            (["arkadan", "arkasından", "ters ışık", "ters ışıkta"], ["light.back"]),
            (["önden", "önünden"], ["light.front"]),
            (["tepeden", "yukarıdan", "üstten"], ["light.top", "angle.topDown"]),
            (["kuşbakışı"], ["angle.topDown"]),
            (["göz hizası", "göz hizasında", "göz hizasından"], ["angle.eyeLevel"]),
            (["eğik", "eğimli", "açılı", "çapraz"], ["angle.angled"]),
            // The reading has no "from below" angle (spec 05 netleştirme 4): never allowed.
            (["aşağıdan", "alttan", "aşağıdan bakılarak"], []),
            (["sıcak"], ["color.warm"]),
            (["soğuk", "serin"], ["color.cool"]),
            (["canlı"], ["color.warmVivid", "color.coolVivid", "color.naturalVivid"]),
            (["soluk"], ["color.warmMuted", "color.coolMuted", "color.naturalMuted"]),
            (["siyah beyaz", "siyah-beyaz"], ["color.mono"]),
            (["yumuşak"], soft),
            (["sert"], ["light.hard"]),
            (["aydınlık", "parlak"], ["tone.bright"]),
            (["karanlık", "loş"], dark),
            (["derin"], ["shadows.deep"]),
        ])

        static let english = entries([
            (["from the left"], ["light.left"]),
            (["from the right"], ["light.right"]),
            (["left"], left),
            (["right"], right),
            (["behind", "backlit", "backlight", "backlighting"], ["light.back"]),
            (["from the front", "front light", "frontal"], ["light.front"]),
            (["above", "overhead", "from the top"], ["light.top", "angle.topDown"]),
            (["top down", "bird's eye", "bird’s eye"], ["angle.topDown"]),
            (["eye level"], ["angle.eyeLevel"]),
            (["angled", "an angle", "tilted"], ["angle.angled"]),
            (["from below", "low angle", "looking up"], []),
            (["warm"], ["color.warm"]),
            (["cool", "cold"], ["color.cool"]),
            (["vivid", "vibrant", "saturated"], ["color.warmVivid", "color.coolVivid", "color.naturalVivid"]),
            (["muted", "faded"], ["color.warmMuted", "color.coolMuted", "color.naturalMuted"]),
            (["black and white", "monochrome"], ["color.mono"]),
            (["soft", "gentle"], soft),
            (["hard", "harsh"], ["light.hard"]),
            (["bright"], ["tone.bright"]),
            (["dark", "dim", "moody"], dark),
            (["deep"], ["shadows.deep"]),
        ])

        /// Turkish: matched by word start, so suffixed forms ("fincanı", "tabakta") are caught; a few look-alike
        /// words are let through ("kahverengi" is a color). English: the word or its plural.
        static let turkishNouns = ["fincan", "kahve", "latte", "tabak", "yemek", "pasta", "çiçek", "içecek",
                                   "bardak", "kupa", "kadın", "adam", "erkek"]
        static let turkishLookAlikes = ["kahverengi", "adamakıllı"]
        static let englishNouns = ["cup", "coffee", "latte", "plate", "food", "cake", "dessert", "flower", "drink",
                                   "mug", "glass", "woman", "women", "man", "men", "girl", "boy"]

        static func namedSubjects(in words: [String], language: String) -> [String] {
            if language == "tr" {
                return turkishNouns.filter { noun in
                    words.contains { $0.hasPrefix(noun) && !turkishLookAlikes.contains(where: $0.hasPrefix) }
                }
            }
            return englishNouns.filter { noun in words.contains { $0 == noun || $0 == noun + "s" || $0 == noun + "es" } }
        }
    }
}
