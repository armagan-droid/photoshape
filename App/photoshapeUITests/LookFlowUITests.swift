import XCTest

/// Spec 03 flows in the simulator (simulated camera, bundled looks).
@MainActor
final class LookFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        return app
    }

    private static let order = ["natural", "morning-light", "coffee-break", "moody-table", "old-film", "vivid"]

    /// Scrolls the strip until the look is on screen, then taps it.
    private func select(_ id: String, in app: XCUIApplication) {
        let item = app.descendants(matching: .any)["look.\(id)"]
        let strip = app.scrollViews["lookStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        XCTAssertTrue(item.waitForExistence(timeout: 5), id)
        let window = app.windows.firstMatch.frame
        func onScreen() -> Bool { window.insetBy(dx: 8, dy: 0).contains(CGPoint(x: item.frame.midX, y: item.frame.midY)) }
        for _ in 0..<8 where !onScreen() {
            let current = Self.order.firstIndex { app.descendants(matching: .any)["look.\($0)"].isSelected } ?? 0
            let target = Self.order.firstIndex(of: id) ?? 0
            let from = strip.coordinate(withNormalizedOffset: CGVector(dx: target > current ? 0.7 : 0.3, dy: 0.5))
            let to = strip.coordinate(withNormalizedOffset: CGVector(dx: target > current ? 0.45 : 0.55, dy: 0.5))
            from.press(forDuration: 0.05, thenDragTo: to)
            sleep(1)
        }
        XCTAssertTrue(onScreen(), id)
        item.tap()
        let selected = NSPredicate(format: "isSelected == true")
        expectation(for: selected, evaluatedWith: item)
        waitForExpectations(timeout: 5)
        sleep(1) // let the preview draw a few frames
    }

    /// Mean RGB of the preview, sampled on a grid.
    private func previewColor(_ app: XCUIApplication) -> (r: Double, g: Double, b: Double) {
        let image = app.descendants(matching: .any)["preview"].screenshot().image
        guard let cg = image.cgImage else { return (0, 0, 0) }
        let w = 40, h = 50
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var r = 0.0, g = 0.0, b = 0.0
        for i in stride(from: 0, to: px.count, by: 4) { r += Double(px[i]); g += Double(px[i + 1]); b += Double(px[i + 2]) }
        let n = Double(w * h)
        return (r / n, g / n, b / n)
    }

    func testLooksChangeThePreviewAndStrengthZeroMatchesNatural() {
        let app = launch()
        select("natural", in: app)
        let natural = previewColor(app)
        XCTAssertFalse(app.sliders["strength"].isEnabled, "no strength for Natural")

        select("moody-table", in: app)
        let moody = previewColor(app)
        XCTAssertLessThan(moody.r + moody.g + moody.b, natural.r + natural.g + natural.b - 30, "Moody Table is darker")

        let slider = app.sliders["strength"]
        XCTAssertTrue(slider.isEnabled)
        slider.adjust(toNormalizedSliderPosition: 0)
        sleep(1)
        let zero = previewColor(app)
        XCTAssertEqual(zero.r, natural.r, accuracy: 3)
        XCTAssertEqual(zero.b, natural.b, accuracy: 3)
        slider.adjust(toNormalizedSliderPosition: 1) // leave it as found for the next runs
    }

    func testSelectedLookAndItsStrengthAreRemembered() {
        var app = launch()
        select("old-film", in: app)
        app.sliders["strength"].adjust(toNormalizedSliderPosition: 0.3)
        sleep(1)
        let value = app.sliders["strength"].normalizedSliderPosition
        app.terminate()

        app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["look.old-film"].isSelected, "last look comes back")
        XCTAssertEqual(app.sliders["strength"].normalizedSliderPosition, value, accuracy: 0.05, "per-look strength")

        select("vivid", in: app)
        XCTAssertGreaterThan(app.sliders["strength"].normalizedSliderPosition, 0.9, "other looks keep their own strength")
        select("old-film", in: app)
        app.sliders["strength"].adjust(toNormalizedSliderPosition: 1)
        select("natural", in: app)
    }

    func testCaptureWithALook() {
        let app = launch()
        select("coffee-break", in: app)
        app.buttons["shutter"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 2) {
            springboard.alerts.firstMatch.buttons.element(boundBy: springboard.alerts.firstMatch.buttons.count - 1).tap()
        }
        XCTAssertTrue(app.buttons["lastPhoto"].waitForExistence(timeout: 10))
        app.buttons["lastPhoto"].tap()
        XCTAssertTrue(app.images["reviewImage"].waitForExistence(timeout: 5))
        app.buttons["close"].tap()
        select("natural", in: app)
    }

    func testLockedLookCanBeTriedButNotCaptured() {
        let app = launch(["-LockedLooks", "vivid"])
        select("vivid", in: app)
        let shutter = app.buttons["shutter"]
        XCTAssertTrue(shutter.label.localizedCaseInsensitiveContains("locked"))
        shutter.tap()
        XCTAssertFalse(app.buttons["lastPhoto"].waitForExistence(timeout: 3), "no capture with a locked look")
        select("natural", in: app)
        XCTAssertFalse(app.buttons["shutter"].label.localizedCaseInsensitiveContains("locked"))
    }
}
