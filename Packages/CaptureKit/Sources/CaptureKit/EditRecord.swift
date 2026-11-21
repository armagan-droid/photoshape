import Foundation

/// What the app changed, stored with the photo as Photos adjustment data (FR-004, FR-005).
/// Photos keeps the untouched original, so "Revert" brings it back.
///
/// Forward compatible: unknown keys are ignored when decoding, so spec 03 can add the look
/// (recipe id, recipe version, strength) as optional fields without a format bump.
public struct EditRecord: Codable, Sendable, Hashable {
    public static let formatVersion = "1"

    public var appVersion: String
    /// The 4:5 crop of the upright original.
    public var crop: NormalizedRect
    /// The look applied, if any (spec 03 FR-005). Absent for "Doğal" and for spec 01 photos.
    public var look: LookReference?

    public init(appVersion: String, crop: NormalizedRect, look: LookReference? = nil) {
        self.appVersion = appVersion
        self.crop = crop
        self.look = look
    }

    public struct LookReference: Codable, Sendable, Hashable {
        public var id: String
        public var version: Int
        /// 0…1
        public var strength: Double
        public init(id: String, version: Int, strength: Double) { self.id = id; self.version = version; self.strength = strength }
    }

    /// The default 4:5 crop for an upright image of this size.
    public static func `default`(appVersion: String, orientedWidth: Int, orientedHeight: Int, look: LookReference? = nil) -> EditRecord {
        let p = CropGeometry.pixelCrop(width: orientedWidth, height: orientedHeight)
        let w = Double(max(orientedWidth, 1)), h = Double(max(orientedHeight, 1))
        return EditRecord(appVersion: appVersion,
                          crop: NormalizedRect(x: Double(p.x) / w, y: Double(p.y) / h, w: Double(p.w) / w, h: Double(p.h) / h),
                          look: look)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data, formatVersion: String) throws -> EditRecord {
        guard formatVersion == Self.formatVersion else { throw Error.unsupportedVersion(formatVersion) }
        return try JSONDecoder().decode(EditRecord.self, from: data)
    }

    /// Whether adjustment data found on a photo was written by this app in a version it understands.
    public static func canHandle(formatIdentifier: String, formatVersion: String, appIdentifier: String) -> Bool {
        formatIdentifier == appIdentifier && formatVersion == Self.formatVersion
    }

    public enum Error: Swift.Error, Equatable {
        case unsupportedVersion(String)
    }
}
