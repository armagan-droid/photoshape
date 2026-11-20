/// Human-entered labels for one test frame (spec 00 "Etiketleme yapısı").
/// Raw values are the exact strings written in label files.

public protocol LabelValue: RawRepresentable, CaseIterable, Hashable, Sendable where RawValue == String {}

public enum Category: String, LabelValue {
    case cafeFood = "cafe_food"
    // FR-007: `travel`, `portrait` are added here when their specs land. Adding a case never breaks existing files.
}

/// Same list as spec 04's composition templates.
public enum SceneType: String, LabelValue {
    case drinkCloseup = "drink_closeup"
    case foodTopDown = "food_top_down"
    case foodAngled = "food_angled"
    case tableSpread = "table_spread"
    case cafeInterior = "cafe_interior"
    case other
}

public enum LightCondition: String, LabelValue {
    case windowDaylight = "window_daylight"
    case outdoorDaylight = "outdoor_daylight"
    case warmIndoor = "warm_indoor"
    case coolIndoor = "cool_indoor"
    case mixed
    case backlit
    case dim
}

public enum ExposureLabel: String, LabelValue { case good, under, over }

public enum WhiteBalanceLabel: String, LabelValue {
    case neutral
    case warmCast = "warm_cast"
    case coolCast = "cool_cast"
    case greenMagentaCast = "green_magenta_cast"
}

public enum Sharpness: String, LabelValue {
    case sharp
    case motionBlur = "motion_blur"
    case focusMiss = "focus_miss"
}

public enum CompositionLabel: String, LabelValue { case good, bad }

public enum CompositionIssue: String, LabelValue {
    case tooClose = "too_close"
    case tooFar = "too_far"
    case tilted
    case subjectCut = "subject_cut"
    case clutteredEdges = "cluttered_edges"
    case offCenterUnintended = "off_center_unintended"
    case wrongAngle = "wrong_angle"
}

public enum PeopleVisible: String, LabelValue { case none, hands, faces }

public struct FrameLabels: Sendable, Hashable {
    public var id: String
    public var category: Category
    public var sceneType: SceneType
    public var light: Set<LightCondition>
    public var exposure: ExposureLabel
    public var whiteBalance: WhiteBalanceLabel
    public var highlightsClipped: Bool
    public var sharpness: Sharpness
    public var composition: CompositionLabel
    /// Present exactly when `composition == .bad`.
    public var compositionIssue: CompositionIssue?
    public var peopleVisible: PeopleVisible
    public var pairID: String?
    public var notes: String?
}
