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

/// Optional (2026-11-23): where the camera looks from. Spec 05 SC-007.
public enum CameraAngle: String, LabelValue {
    case topDown = "top_down"
    case angled
    case eyeLevel = "eye_level"
}

/// Optional (2026-11-23): where light reaches the subject from, as seen by the photographer. Spec 05 SC-008.
public enum LightDirection: String, LabelValue { case left, right, front, back, top, diffuse }

/// Optional (2026-11-23): soft or hard shadow edges. Spec 05 SC-009.
public enum LightQuality: String, LabelValue { case soft, hard }

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
    /// Main subject (plate, cup). Expected for scenes with a main subject; see `LabelSchema.gaps(for:)`.
    public var subjectRegion: Region?
    /// Surfaces that are really white or grey. Expected under `warm_indoor` / `mixed` light. Empty when absent.
    public var neutralRegions: [Region]
    public var pairID: String?
    public var notes: String?
    public var cameraAngle: CameraAngle?
    public var lightDirection: LightDirection?
    public var lightQuality: LightQuality?
    /// Spec 06: frames of one series share it; `sharpness` and this count are labeled per frame.
    public var burstID: String? = nil
    public var eyesClosedCount: Int? = nil
}

/// A rectangle in normalized image coordinates: 0–1, origin top-left, in the orientation the
/// Photos app displays (EXIF orientation applied). `TestFrame.loadImage()` returns that same orientation.
public struct Region: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    /// Tolerance for rounding in hand-edited or tool-written files.
    static let epsilon = 1e-6

    /// Pixel rectangle in an image of the given (oriented) size, origin top-left.
    public func pixelRect(width: Int, height: Int) -> (x: Int, y: Int, w: Int, h: Int) {
        let x0 = Int((x * Double(width)).rounded(.down)), y0 = Int((y * Double(height)).rounded(.down))
        let x1 = Int(((x + w) * Double(width)).rounded(.up)), y1 = Int(((y + h) * Double(height)).rounded(.up))
        let cx0 = max(0, min(width, x0)), cy0 = max(0, min(height, y0))
        return (cx0, cy0, max(0, min(width, x1) - cx0), max(0, min(height, y1) - cy0))
    }

    /// Normalized region from two drag points inside an on-screen image rectangle (both top-left origin).
    /// Points outside the image are clamped; values are rounded to 4 decimals.
    /// Returns nil for a drag smaller than `minimumSize` of the image on either axis.
    public static func fromDrag(start: (x: Double, y: Double), end: (x: Double, y: Double),
                                imageFrame: (x: Double, y: Double, w: Double, h: Double),
                                minimumSize: Double = 0.01) -> Region? {
        guard imageFrame.w > 0, imageFrame.h > 0 else { return nil }
        func nx(_ v: Double) -> Double { min(1, max(0, (v - imageFrame.x) / imageFrame.w)) }
        func ny(_ v: Double) -> Double { min(1, max(0, (v - imageFrame.y) / imageFrame.h)) }
        func r(_ v: Double) -> Double { (v * 10_000).rounded() / 10_000 }
        let x0 = r(min(nx(start.x), nx(end.x))), x1 = r(max(nx(start.x), nx(end.x)))
        let y0 = r(min(ny(start.y), ny(end.y))), y1 = r(max(ny(start.y), ny(end.y)))
        guard x1 - x0 >= minimumSize, y1 - y0 >= minimumSize else { return nil }
        return Region(x: x0, y: y0, w: r(x1 - x0), h: r(y1 - y0))
    }

    var jsonObject: [String: Double] { ["x": x, "y": y, "w": w, "h": h] }
}
