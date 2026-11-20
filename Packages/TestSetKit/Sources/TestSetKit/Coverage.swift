/// Minimum counts from spec 00 "Zor durum kotaları" plus the SC-002 size gate.
/// Brain specs' acceptance criteria count as "measured" only when every quota is met.
public struct Quota: Sendable {
    public let id: String
    public let title: String
    public let required: Int
    let count: @Sendable ([TestFrame]) -> Int

    static func frames(_ id: String, _ title: String, _ required: Int,
                       _ predicate: @escaping @Sendable (TestFrame) -> Bool) -> Quota {
        Quota(id: id, title: title, required: required) { $0.filter(predicate).count }
    }

    public static let spec00: [Quota] = {
        var q: [Quota] = [
            Quota(id: "min_frames", title: "total frames (SC-002)", required: 30) { $0.count },
            .frames("light_mixed", "light = mixed", 5) { $0.labels.light.contains(.mixed) },
            .frames("light_backlit", "light = backlit", 5) { $0.labels.light.contains(.backlit) },
            .frames("light_dim", "light = dim", 5) { $0.labels.light.contains(.dim) },
            .frames("light_warm_indoor", "light = warm_indoor", 5) { $0.labels.light.contains(.warmIndoor) },
            .frames("exposure_under", "exposure = under", 4) { $0.labels.exposure == .under },
            .frames("exposure_over", "exposure = over", 4) { $0.labels.exposure == .over },
            .frames("highlights_clipped", "highlights_clipped = true", 3) { $0.labels.highlightsClipped },
            .frames("composition_bad", "composition = bad", 8) { $0.labels.composition == .bad },
        ]
        for issue in CompositionIssue.allCases {
            q.append(.frames("composition_issue_\(issue.rawValue)", "composition_issue = \(issue.rawValue)", 1) {
                $0.labels.compositionIssue == issue
            })
        }
        q.append(.frames("has_depth", "has_depth = true", 10) { $0.metadata.hasDepth })
        for scene in SceneType.allCases where scene != .other {
            q.append(.frames("scene_type_\(scene.rawValue)", "scene_type = \(scene.rawValue)", 3) {
                $0.labels.sceneType == scene
            })
        }
        q.append(Quota(id: "good_bad_pairs", title: "good/bad pairs via pair_id", required: 5, count: goodBadPairCount))
        return q
    }()

    /// A `pair_id` group is a good/bad pair if it has both a good and a not-good frame
    /// for exposure, or for composition (plan: "Yorumlar").
    static func goodBadPairCount(_ frames: [TestFrame]) -> Int {
        let groups = Dictionary(grouping: frames.filter { $0.labels.pairID != nil }) { $0.labels.pairID! }
        return groups.values.filter { group in
            let exposure = Set(group.map { $0.labels.exposure == .good })
            let composition = Set(group.map { $0.labels.composition == .good })
            return exposure.count == 2 || composition.count == 2
        }.count
    }
}

public struct QuotaStatus: Sendable {
    public let id: String
    public let title: String
    public let required: Int
    public let actual: Int
    public var isMet: Bool { actual >= required }
}

public struct CoverageReport: Sendable {
    public let frameCount: Int
    /// field → value → count, over valid frames. Includes zero counts and the automatic `has_depth`.
    public let distribution: [String: [String: Int]]
    public let quotas: [QuotaStatus]

    public var allQuotasMet: Bool { quotas.allSatisfy(\.isMet) }
    public func quota(_ id: String) -> QuotaStatus? { quotas.first { $0.id == id } }

    public init(_ set: TestSet, quotas: [Quota] = Quota.spec00) {
        let frames = set.frames
        frameCount = frames.count

        func counts<T: LabelValue>(_: T.Type, _ value: (FrameLabels) -> [T]) -> [String: Int] {
            var result = Dictionary(uniqueKeysWithValues: T.allCases.map { ($0.rawValue, 0) })
            for frame in frames { for v in value(frame.labels) { result[v.rawValue, default: 0] += 1 } }
            return result
        }
        func bools(_ value: (TestFrame) -> Bool) -> [String: Int] {
            let yes = frames.filter(value).count
            return ["true": yes, "false": frames.count - yes]
        }

        distribution = [
            "category": counts(Category.self) { [$0.category] },
            "scene_type": counts(SceneType.self) { [$0.sceneType] },
            "light": counts(LightCondition.self) { Array($0.light) },
            "exposure": counts(ExposureLabel.self) { [$0.exposure] },
            "white_balance": counts(WhiteBalanceLabel.self) { [$0.whiteBalance] },
            "highlights_clipped": bools { $0.labels.highlightsClipped },
            "sharpness": counts(Sharpness.self) { [$0.sharpness] },
            "composition": counts(CompositionLabel.self) { [$0.composition] },
            "composition_issue": counts(CompositionIssue.self) { $0.compositionIssue.map { [$0] } ?? [] },
            "people_visible": counts(PeopleVisible.self) { [$0.peopleVisible] },
            "subject_region": bools { $0.labels.subjectRegion != nil },
            "neutral_region": bools { !$0.labels.neutralRegions.isEmpty },
            "has_depth": bools { $0.metadata.hasDepth },
        ]
        self.quotas = quotas.map { QuotaStatus(id: $0.id, title: $0.title, required: $0.required, actual: $0.count(frames)) }
    }
}
