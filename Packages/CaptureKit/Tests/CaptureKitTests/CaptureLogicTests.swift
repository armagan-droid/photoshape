import Foundation
import Testing
@testable import CaptureKit

@Suite("4:5 crop geometry (FR-002, SC-005)")
struct CropGeometryTests {
    @Test(arguments: [(3024, 4032), (4284, 5712), (1512, 2016), (1080, 1920), (3000, 3000), (1001, 1333), (4032, 3024)])
    func pixelCropIsExactlyFourByFiveAndCentered(width: Int, height: Int) {
        let r = CropGeometry.pixelCrop(width: width, height: height)
        #expect(r.w * 5 == r.h * 4, "exact 4:5")
        #expect(r.x >= 0 && r.y >= 0 && r.x + r.w <= width && r.y + r.h <= height)
        // Largest possible: one more 4:5 step would not fit.
        #expect(r.w + 4 > width || r.h + 5 > height)
        #expect(abs((width - r.w) - 2 * r.x) <= 1 && abs((height - r.h) - 2 * r.y) <= 1)
    }

    @Test func iPhone12FullResolutionCrop() {
        let r = CropGeometry.pixelCrop(width: 3024, height: 4032)
        #expect(r.x == 0 && r.w == 3024 && r.h == 3780 && r.y == 126)
    }

    @Test func normalizedCropMatchesPixelCrop() {
        // The preview overlay uses the normalized crop; saving uses the pixel crop. They must agree.
        let n = CropGeometry.normalizedCrop(aspectWidth: 3, aspectHeight: 4)
        #expect(n == NormalizedRect(x: 0, y: 0.03125, w: 1, h: 0.9375))
        let p = CropGeometry.pixelCrop(width: 3024, height: 4032)
        #expect(abs(n.y * 4032 - Double(p.y)) < 1 && abs(n.h * 4032 - Double(p.h)) < 1)
    }

    @Test func snappingAnArbitraryRectKeepsExactAspectInside() {
        let r = CropGeometry.snap(NormalizedRect(x: 0.1, y: 0.1, w: 0.5, h: 0.6), width: 1000, height: 1000)
        #expect(r.w * 5 == r.h * 4)
        #expect(r.x >= 100 && r.y >= 100 && r.x + r.w <= 600 && r.y + r.h <= 700)
    }
}

@Suite("Lens catalog (Hikâye 2, FR-007)")
struct LensCatalogTests {
    private func zooms(_ caps: CameraCapabilities) -> [LensKind: Double] {
        Dictionary(uniqueKeysWithValues: LensCatalog.options(for: caps).map { ($0.kind, $0.zoomFactor) })
    }

    @Test func tripleCameraUsesEveryLens() {
        let options = LensCatalog.options(for: .init(hasUltraWide: true, hasTelephoto: true, switchOverZoomFactors: [2, 6], maxZoomFactor: 30))
        #expect(options.map(\.kind) == [.wide, .normal, .close])
        #expect(options.map(\.zoomFactor) == [1, 2, 6])
        #expect(options.allSatisfy { !$0.isDigital })
    }

    @Test func iPhone12DualWideGetsDigitalClose() {
        let options = LensCatalog.options(for: .init(hasUltraWide: true, hasTelephoto: false, switchOverZoomFactors: [2], maxZoomFactor: 10))
        #expect(options.map(\.kind) == [.wide, .normal, .close])
        #expect(options.map(\.zoomFactor) == [1, 2, 4])
        #expect(options.last?.isDigital == true)
    }

    @Test func noUltraWideHidesWideButton() {
        #expect(zooms(.init(hasUltraWide: false, hasTelephoto: true, switchOverZoomFactors: [2], maxZoomFactor: 10)) == [.normal: 1, .close: 2])
        #expect(zooms(.init(hasUltraWide: false, hasTelephoto: false, switchOverZoomFactors: [], maxZoomFactor: 5)) == [.normal: 1, .close: 2])
    }

    @Test func inconsistentCapabilitiesFallBackQuietly() {
        // Claims a telephoto but reports no switch-over: digital close from the normal lens, no crash.
        #expect(zooms(.init(hasUltraWide: true, hasTelephoto: true, switchOverZoomFactors: [2], maxZoomFactor: 10)) == [.wide: 1, .normal: 2, .close: 4])
        // Max zoom too small for a distinct close option: close is dropped rather than duplicating normal.
        #expect(zooms(.init(hasUltraWide: false, hasTelephoto: false, switchOverZoomFactors: [], maxZoomFactor: 1)) == [.normal: 1])
    }

    @Test func defaultIsNormal() {
        #expect(LensKind.default == .normal)
    }
}

@Suite("Shutter gate (rapid presses)")
struct ShutterGateTests {
    @Test func pressesDuringCaptureAreIgnoredWithoutQueueing() {
        var gate = ShutterGate()
        do { let started = gate.press(at: 0); #expect(started) }
        do { let started = gate.press(at: 0.05); #expect(!started) }
        do { let started = gate.press(at: 0.1); #expect(!started) }
        gate.finish()
        do { let started = gate.press(at: 0.2); #expect(started) }
    }

    @Test func aStuckCaptureReleasesAfterTimeout() {
        var gate = ShutterGate(timeout: 5)
        do { let started = gate.press(at: 0); #expect(started) }
        do { let started = gate.press(at: 4.9); #expect(!started) }
        do { let started = gate.press(at: 5.1); #expect(started) }
    }
}

@Suite("Edit record (FR-004, FR-005)")
struct EditRecordTests {
    @Test func roundTrips() throws {
        let record = EditRecord(appVersion: "1.0 (1)", crop: NormalizedRect(x: 0, y: 0.03125, w: 1, h: 0.9375))
        let decoded = try EditRecord.decode(record.encoded(), formatVersion: EditRecord.formatVersion)
        #expect(decoded == record)
    }

    @Test func toleratesFutureFields() throws {
        // Spec 03 will add the look (recipe id, version, strength). Older readers must still decode.
        let json = #"{"appVersion":"2.0","crop":{"x":0,"y":0,"w":0.8,"h":1},"look":{"id":"morning","version":3,"strength":0.7}}"#
        let decoded = try EditRecord.decode(Data(json.utf8), formatVersion: "1")
        #expect(decoded.crop.w == 0.8)
    }

    @Test func rejectsUnknownFormatVersion() {
        #expect(throws: EditRecord.Error.self) { try EditRecord.decode(Data("{}".utf8), formatVersion: "99") }
        #expect(EditRecord.canHandle(formatIdentifier: "app.x", formatVersion: "1", appIdentifier: "app.x"))
        #expect(!EditRecord.canHandle(formatIdentifier: "com.other", formatVersion: "1", appIdentifier: "app.x"))
    }
}
