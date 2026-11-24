import CompositionKit
import CoreImage
import Foundation
import LookKit
import UIKit

/// Example photos the user picked ("Örneklerim", spec 05 FR-007). Only a small icon and the statistics are
/// kept, never the full image (Hikâye 6.2); nothing leaves the device (Constitution I).
@MainActor @Observable
final class ReferenceStore {
    struct Reference: Codable, Identifiable, Hashable {
        let id: UUID
        let created: Date
        let profile: ReferenceProfile
        /// Main subject of the example (person with pose, or object), in the example's own coordinates (spec 04).
        var subject: Subject?
        /// Width / height of the example, to fit it into the 4:5 frame.
        var aspect: Double?
        /// How the example's subject is lit (spec 04 FR-L1, spec 05 FR-013). The card and the live advice use
        /// this same reading, so they cannot disagree.
        var light: LightReading?
        /// Where the example was shot from (spec 05 FR-012). Nil when unsure or saved before 2026-11-23.
        var angle: ShotAngleEstimate?
        /// Shutter, aperture, ISO… from the photo's own camera data (spec 05 Hikâye 8). Nil for screenshots.
        var settings: ExampleSettings?
        /// Short summary by the on-device model, per language ("tr", "en") (spec 05 Hikâye 9, FR-028).
        var summaries: [String: String]?

        /// Approximate values read from the picture (spec 05 FR-020).
        var measurements: ExampleMeasurements { ExampleMeasurements(stats: profile.stats) }

        /// The "how was this shot" card (spec 05 Hikâye 7); computed from what is stored (FR-017).
        var reading: ExampleReading {
            ExampleReading(tone: profile.stats, isMonochrome: profile.isMonochrome, subject: subject, light: light, angle: angle)
        }
    }

    private(set) var references: [Reference] = []
    private(set) var currentID: UUID?
    private(set) var isAnalyzing = false
    /// Set when the last picked image could not be used.
    private(set) var failedToRead = false
    /// "Örneksiz çek" for this session: the prompt is not shown again until the next launch.
    var skippedPrompt = false
    /// Incremented each time the user picks an example (new or from the list), not at launch: opens the card
    /// (spec 05 Hikâye 7.1).
    private(set) var selectionCount = 0
    /// Set by the camera model: the summary is asked of the single entitlement question (Constitution VII).
    var entitlements: Entitlements = AllUnlocked()
    /// Examples whose summary is being written now; one at a time, never in the live loop (FR-029).
    private var summarizing: Set<String> = []

    private let directory: URL
    private let defaults: UserDefaults
    private var thumbnails: [UUID: UIImage] = [:]
    private var ghosts: [UUID: UIImage] = [:]
    private enum Keys { static let current = "reference.current" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("References", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if DEBUG
        if defaults.bool(forKey: "ResetReferences") { try? FileManager.default.removeItem(at: indexURL); defaults.removeObject(forKey: Keys.current) }
        #endif
        if let data = try? Data(contentsOf: indexURL), let list = try? JSONDecoder().decode([Reference].self, from: data) {
            references = list
        }
        let saved = defaults.string(forKey: Keys.current).flatMap(UUID.init)
        currentID = references.contains { $0.id == saved } ? saved : nil
    }

    var current: Reference? { references.first { $0.id == currentID } }

    func select(_ id: UUID?) {
        currentID = id
        defaults.set(id?.uuidString, forKey: Keys.current)
        if id != nil { selectionCount += 1 }
    }

    /// "Örneksiz çek" from the examples list: back to the plain camera, not to the first-launch prompt.
    func shootWithoutExample() {
        select(nil)
        skippedPrompt = true
    }

    func delete(_ id: UUID) {
        references.removeAll { $0.id == id }
        thumbnails[id] = nil
        try? FileManager.default.removeItem(at: thumbnailURL(id))
        try? FileManager.default.removeItem(at: ghostURL(id))
        ghosts[id] = nil
        if currentID == id { shootWithoutExample() }
        saveIndex()
    }

    func thumbnail(_ id: UUID) -> UIImage? {
        if let cached = thumbnails[id] { return cached }
        let image = UIImage(contentsOfFile: thumbnailURL(id).path)
        thumbnails[id] = image
        return image
    }

    /// Outline of the example drawn over the live view (spec 04 "Taslak", Constitution 1.2.0).
    func ghost(_ id: UUID) -> UIImage? {
        if let cached = ghosts[id] { return cached }
        let image = UIImage(contentsOfFile: ghostURL(id).path)
        ghosts[id] = image
        return image
    }

    /// Analyzes a picked image off the main thread, stores it and makes it current.
    func add(imageData: Data) async {
        isAnalyzing = true
        failedToRead = false
        defer { isAnalyzing = false }
        let result = await Task.detached(priority: .userInitiated) { () -> Analysis? in
            guard let full = Self.upright(imageData, maxSide: 1600) else { return nil }
            let settings = Self.cameraData(imageData)
            // A screenshot (no camera data): only the photo inside it, without the app's bars (FR-003, Hikâye 1.2).
            let region = settings == nil ? ScreenshotCrop.photoRegion(in: full) : nil
            let photo = region.flatMap { r in
                full.cropping(to: CGRect(x: r.minX * CGFloat(full.width), y: r.minY * CGFloat(full.height),
                                         width: r.width * CGFloat(full.width), height: r.height * CGFloat(full.height)).integral)
            } ?? full
            guard let upright = Self.scaled(photo, maxSide: 1024), let sample = SceneSample(image: upright),
                  let thumb = Self.scaled(photo, maxSide: 300).flatMap({ UIImage(cgImage: $0).jpegData(compressionQuality: 0.85) })
            else { return nil }
            if let region { Diagnostics.log("screenshot: photo region \(region)") }
            let subject = SubjectDetector.detect(in: upright)
            // Finer grid for the card's light character (spec 05 FR-013); the middle stands in without a subject.
            let light = LuminanceGrid(image: upright).flatMap { LightAnalyzer.readExample($0, subject: subject?.box) }
            // People's skin stays out of the colors (FR-004, Hikâye 4): only when the example has a person.
            let skin = subject?.kind == .person
                ? PersonMask.grid(for: upright, width: SceneSample.gridWidth, height: SceneSample.gridHeight)
                    .map { SkinTone.skinCells(colors: sample.colors, personMask: $0) }
                : nil
            if let skin { Diagnostics.log("skin cells left out: \(skin.filter { $0 }.count) of \(skin.count)") }
            return Analysis(profile: ReferenceProfile(sample: sample, excluding: skin), subject: subject, light: light,
                            angle: ShotAngleEstimator.estimate(in: upright),
                            settings: settings,
                            aspect: Double(upright.width) / Double(max(upright.height, 1)),
                            thumbnail: thumb, ghost: Self.outline(of: upright))
        }.value
        guard let result else { failedToRead = true; return }
        let reference = Reference(id: UUID(), created: Date(), profile: result.profile, subject: result.subject,
                                  aspect: result.aspect, light: result.light, angle: result.angle, settings: result.settings)
        try? result.thumbnail.write(to: thumbnailURL(reference.id))
        try? result.ghost?.write(to: ghostURL(reference.id))
        let profile = result.profile
        references.insert(reference, at: 0)
        saveIndex()
        select(reference.id)
        Diagnostics.log("reference added: meanL \(profile.stats.meanL), chroma \(profile.stats.meanChroma), neutralB \(profile.stats.neutralB ?? .nan), subject \(result.subject?.kind.rawValue ?? "none"), angle \(String(describing: result.angle)), light \(String(describing: result.light))")
        Diagnostics.log("settings: \(String(describing: result.settings))")
        Diagnostics.log("reading: \(reference.reading.lines.flatMap(\.phraseKeys)) steps \(reference.reading.steps)")
        summarize(reference.id)
    }

    // MARK: - Summary (spec 05 Hikâye 9)

    /// The app's language: the summary is written and shown in it (9.5).
    static var language: String { Bundle.main.preferredLocalizations.first == "tr" ? "tr" : "en" }

    /// Read from the stored list, so an open card shows the summary as soon as it is written (9.1).
    func summary(for id: UUID) -> String? { references.first { $0.id == id }?.summaries?[Self.language] }

    /// Writes the summary in the app's language if it is missing. Safe to call often: once per example and
    /// language at a time; a failed attempt is simply not stored (the card shows no summary).
    func summarize(_ id: UUID) {
        let language = Self.language
        guard entitlements.isAvailable(.exampleSummary),
              let reference = references.first(where: { $0.id == id }), reference.summaries?[language] == nil else { return }
        let key = "\(id.uuidString)-\(language)"
        guard !summarizing.contains(key) else { return }
        summarizing.insert(key)
        let input = ExampleSummaryInput(reading: reference.reading, language: language)
        Task {
            let text = await Task.detached(priority: .background) { await ExampleSummaryWriter.write(input) }.value
            summarizing.remove(key)
            guard let text, let index = references.firstIndex(where: { $0.id == id }) else { return }
            references[index].summaries = (references[index].summaries ?? [:]).merging([language: text]) { $1 }
            saveIndex()
        }
    }

    // MARK: - Files

    private var indexURL: URL { directory.appendingPathComponent("references.json") }
    private func thumbnailURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).jpg") }
    private func ghostURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString)-ghost.png") }

    private struct Analysis: Sendable {
        let profile: ReferenceProfile
        let subject: Subject?
        let light: LightReading?
        let angle: ShotAngleEstimate?
        let settings: ExampleSettings?
        let aspect: Double
        let thumbnail: Data
        let ghost: Data?
    }

    /// White edge lines on transparent, ≤ 720 px: enough to line up with, not a copy of the photo.
    nonisolated static func outline(of image: CGImage) -> Data? {
        let input = CIImage(cgImage: image)
        let scale = min(1, 720 / max(input.extent.width, input.extent.height))
        let edges = input
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingGaussianBlur(sigma: 1.2)
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.6])
            .applyingFilter("CIMaskToAlpha")
        let extent = CGRect(x: 0, y: 0, width: (input.extent.width * scale).rounded(), height: (input.extent.height * scale).rounded())
        let context = CIContext()
        guard let cg = context.createCGImage(edges.cropped(to: extent), from: extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(references) { try? data.write(to: indexURL, options: .atomic) }
    }

    /// Shooting values from the file's camera data; only `ExampleSettings` fields are read (spec 05 FR-019).
    nonisolated static func cameraData(_ data: Data) -> ExampleSettings? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        return ExampleSettings(properties: props)
    }

    /// The image with its long side limited (never enlarged).
    nonisolated static func scaled(_ image: CGImage, maxSide: Int) -> CGImage? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        if scale == 1 { return image }
        let w = max(1, Int((Double(image.width) * scale).rounded())), h = max(1, Int((Double(image.height) * scale).rounded()))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    /// Decodes with EXIF orientation applied and the long side limited.
    nonisolated static func upright(_ data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

extension SceneSample {
    /// The same sample as a brightness grid for light analysis.
    var luminanceGrid: LuminanceGrid {
        LuminanceGrid(width: SceneSample.gridWidth, height: SceneSample.gridHeight,
                      values: colors.map { 0.2126 * $0.x + 0.7152 * $0.y + 0.0722 * $0.z })
    }
}
