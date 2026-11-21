/// The three lens buttons (Constitution II): no numbers are shown to the user.
public enum LensKind: String, CaseIterable, Sendable, Codable {
    case wide, normal, close
    public static let `default`: LensKind = .normal
}

/// What the camera device offers, as plain values (read from `AVCaptureDevice` in the app).
/// Zoom factors are in the device's own scale: for a virtual device 1.0 is its widest constituent lens.
public struct CameraCapabilities: Sendable, Hashable {
    public var hasUltraWide: Bool
    public var hasTelephoto: Bool
    /// `virtualDeviceSwitchOverVideoZoomFactors`, ascending. Empty for a single-lens device.
    public var switchOverZoomFactors: [Double]
    public var maxZoomFactor: Double

    public init(hasUltraWide: Bool, hasTelephoto: Bool, switchOverZoomFactors: [Double], maxZoomFactor: Double) {
        self.hasUltraWide = hasUltraWide
        self.hasTelephoto = hasTelephoto
        self.switchOverZoomFactors = switchOverZoomFactors
        self.maxZoomFactor = maxZoomFactor
    }
}

public struct LensOption: Sendable, Hashable {
    public var kind: LensKind
    public var zoomFactor: Double
    /// True when "close" is a crop of the normal lens rather than a telephoto lens.
    public var isDigital: Bool
}

/// Maps device capabilities to the lens buttons (spec 01 Hikâye 2, FR-007, karar 2).
/// Never fails: inconsistent input degrades to fewer or digital options.
public enum LensCatalog {
    /// "Close" without a telephoto lens zooms the normal lens this much (karar 2).
    public static let digitalCloseFactor = 2.0

    public static func options(for caps: CameraCapabilities) -> [LensOption] {
        let switches = caps.switchOverZoomFactors.filter { $0 > 1 }.sorted()
        var options: [LensOption] = []

        let normal: Double
        if caps.hasUltraWide, let first = switches.first {
            options.append(LensOption(kind: .wide, zoomFactor: 1, isDigital: false))
            normal = first
        } else {
            normal = 1
        }
        options.append(LensOption(kind: .normal, zoomFactor: normal, isDigital: false))

        let teleIndex = caps.hasUltraWide ? 1 : 0
        if caps.hasTelephoto, switches.indices.contains(teleIndex), switches[teleIndex] > normal {
            options.append(LensOption(kind: .close, zoomFactor: switches[teleIndex], isDigital: false))
        } else {
            let digital = normal * digitalCloseFactor
            if digital <= caps.maxZoomFactor {
                options.append(LensOption(kind: .close, zoomFactor: digital, isDigital: true))
            }
        }
        return options
    }
}
