import Foundation

/// The single source of truth for the label file format (FR-002).
/// Validation and the exported JSON Schema are both derived from `fields`.
public enum LabelSchema {
    public struct Field: Sendable {
        public enum Kind: Sendable {
            case string
            case boolean
            case oneOf([String])
            case setOf([String])
        }

        public enum Requirement: Sendable {
            case required
            case optional
            /// Required when `key == value`, forbidden otherwise.
            case requiredWhen(key: String, equals: String)
        }

        public let key: String
        public let kind: Kind
        public let requirement: Requirement
        public let summary: String
    }

    public static let fields: [Field] = [
        Field(key: "id", kind: .string, requirement: .required, summary: "File name without extension; unique in the set"),
        Field(key: "category", kind: .oneOf(values(Category.self)), requirement: .required, summary: "Category"),
        Field(key: "scene_type", kind: .oneOf(values(SceneType.self)), requirement: .required,
              summary: "Scene type; same list as spec 04 templates"),
        Field(key: "light", kind: .setOf(values(LightCondition.self)), requirement: .required,
              summary: "Lighting; one or more values"),
        Field(key: "exposure", kind: .oneOf(values(ExposureLabel.self)), requirement: .required,
              summary: "Human judgment: is the frame well exposed?"),
        Field(key: "white_balance", kind: .oneOf(values(WhiteBalanceLabel.self)), requirement: .required,
              summary: "Human judgment: is there a color cast?"),
        Field(key: "highlights_clipped", kind: .boolean, requirement: .required,
              summary: "Blown areas such as a white plate or window"),
        Field(key: "sharpness", kind: .oneOf(values(Sharpness.self)), requirement: .required, summary: "Sharpness"),
        Field(key: "composition", kind: .oneOf(values(CompositionLabel.self)), requirement: .required,
              summary: "Human judgment"),
        Field(key: "composition_issue", kind: .oneOf(values(CompositionIssue.self)),
              requirement: .requiredWhen(key: "composition", equals: CompositionLabel.bad.rawValue),
              summary: "Main problem; only when composition = bad"),
        Field(key: "people_visible", kind: .oneOf(values(PeopleVisible.self)), requirement: .required,
              summary: "For future skin tone tests"),
        Field(key: "pair_id", kind: .string, requirement: .optional,
              summary: "Links attempts of the same scene (e.g. good and badly exposed)"),
        Field(key: "notes", kind: .string, requirement: .optional, summary: "Free text"),
    ]

    /// Read from the image file (FR-005); writing them by hand is an error.
    public static let automaticKeys = ["has_depth", "device", "lens"]

    public static func values<T: LabelValue>(_: T.Type) -> [String] { T.allCases.map(\.rawValue) }

    // MARK: - Validation

    /// Validates a decoded label file. Reports every problem at once, in schema order.
    public static func parse(_ dict: [String: Any], expectedID: String) -> Result<FrameLabels, LabelErrors> {
        var issues: [FieldIssue] = []

        for field in fields {
            let value = dict[field.key]
            let isRequired: Bool
            switch field.requirement {
            case .required: isRequired = true
            case .optional: isRequired = false
            case .requiredWhen(let key, let expected):
                isRequired = (dict[key] as? String) == expected
                if !isRequired, value != nil {
                    issues.append(FieldIssue(field.key, "allowed only when \(key) = \(expected)"))
                    continue
                }
            }
            guard let value else {
                if isRequired { issues.append(FieldIssue(field.key, "missing required field")) }
                continue
            }
            if let problem = check(value, against: field.kind) { issues.append(FieldIssue(field.key, problem)) }
        }

        if let id = dict["id"] as? String, id != expectedID {
            issues.append(FieldIssue("id", "\"\(id)\" does not match file name \"\(expectedID)\""))
        }

        let known = Set(fields.map(\.key))
        for key in automaticKeys where dict[key] != nil {
            issues.append(FieldIssue(key, "automatic field; it is read from the image file, remove it"))
        }
        for key in dict.keys.sorted() where !known.contains(key) && !automaticKeys.contains(key) {
            issues.append(FieldIssue(key, "unknown field"))
        }

        guard issues.isEmpty else { return .failure(LabelErrors(issues: issues)) }

        // All fields are checked above, so force-unwrapping enum initializers is safe here.
        let labels = FrameLabels(
            id: dict["id"] as! String,
            category: Category(rawValue: dict["category"] as! String)!,
            sceneType: SceneType(rawValue: dict["scene_type"] as! String)!,
            light: Set((dict["light"] as! [String]).map { LightCondition(rawValue: $0)! }),
            exposure: ExposureLabel(rawValue: dict["exposure"] as! String)!,
            whiteBalance: WhiteBalanceLabel(rawValue: dict["white_balance"] as! String)!,
            highlightsClipped: (dict["highlights_clipped"] as! NSNumber).boolValue,
            sharpness: Sharpness(rawValue: dict["sharpness"] as! String)!,
            composition: CompositionLabel(rawValue: dict["composition"] as! String)!,
            compositionIssue: (dict["composition_issue"] as? String).flatMap(CompositionIssue.init(rawValue:)),
            peopleVisible: PeopleVisible(rawValue: dict["people_visible"] as! String)!,
            pairID: dict["pair_id"] as? String,
            notes: dict["notes"] as? String
        )
        return .success(labels)
    }

    private static func check(_ value: Any, against kind: Field.Kind) -> String? {
        switch kind {
        case .string:
            guard let s = value as? String, !(value is NSNumber) else { return "expected a string" }
            return s.trimmingCharacters(in: .whitespaces).isEmpty ? "must not be empty" : nil
        case .boolean:
            guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else {
                return "expected true or false"
            }
            return nil
        case .oneOf(let allowed):
            guard let s = value as? String else { return "expected one of: \(allowed.joined(separator: ", "))" }
            return allowed.contains(s) ? nil : "invalid value \"\(s)\"; expected one of: \(allowed.joined(separator: ", "))"
        case .setOf(let allowed):
            guard let array = value as? [Any] else { return "expected an array, e.g. [\"\(allowed[0])\"]" }
            guard !array.isEmpty else { return "must contain at least one value" }
            let strings = array.compactMap { $0 as? String }
            guard strings.count == array.count else { return "every value must be a string" }
            if let bad = strings.first(where: { !allowed.contains($0) }) {
                return "invalid value \"\(bad)\"; expected any of: \(allowed.joined(separator: ", "))"
            }
            return Set(strings).count == strings.count ? nil : "contains duplicate values"
        }
    }

    // MARK: - JSON Schema export (for editor completion; derived, never edited by hand)

    public static func jsonSchema() throws -> Data {
        var properties: [String: Any] = [:]
        for field in fields {
            var p: [String: Any] = ["description": field.summary]
            switch field.kind {
            case .string: p["type"] = "string"; p["minLength"] = 1
            case .boolean: p["type"] = "boolean"
            case .oneOf(let values): p["type"] = "string"; p["enum"] = values
            case .setOf(let values):
                p["type"] = "array"; p["minItems"] = 1; p["uniqueItems"] = true
                p["items"] = ["type": "string", "enum": values]
            }
            properties[field.key] = p
        }
        var conditionals: [[String: Any]] = []
        for field in fields {
            guard case .requiredWhen(let key, let value) = field.requirement else { continue }
            conditionals.append([
                "if": ["properties": [key: ["const": value]], "required": [key]],
                "then": ["required": [field.key]],
                "else": ["not": ["required": [field.key]]],
            ])
        }
        let schema: [String: Any] = [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "photoshape test frame labels (spec 00)",
            "type": "object",
            "properties": properties,
            "required": fields.filter { if case .required = $0.requirement { true } else { false } }.map(\.key),
            "additionalProperties": false,
            "allOf": conditionals,
        ]
        return try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}

public struct FieldIssue: Sendable, Hashable {
    public let field: String
    public let message: String
    init(_ field: String, _ message: String) { self.field = field; self.message = message }
}

public struct LabelErrors: Error, Sendable {
    public let issues: [FieldIssue]
}
