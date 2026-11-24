import XCTest

/// Spec 05 step 1 in the simulator: start from an example photo, the camera follows it.
/// The system photo picker cannot be driven reliably, so tests add a bundled sample with `-UITestReference`.
@MainActor
final class ReferenceFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String], language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "tr" ? "tr_TR" : "en_US"] + arguments
        app.launch()
        return app
    }

    /// Every pick opens the example card (spec 05 Hikâye 7.1); start shooting closes it.
    private func closeCard(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["card.start"].waitForExistence(timeout: 10), "card opens after picking an example")
        app.buttons["card.start"].tap()
        XCTAssertTrue(app.buttons["card.start"].waitForNonExistence(timeout: 5))
    }

    private func previewBrightness(_ app: XCUIApplication) -> Double {
        let image = app.descendants(matching: .any)["preview"].screenshot().image
        guard let cg = image.cgImage else { return 0 }
        let w = 30, h = 40
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum = 0.0
        for i in stride(from: 0, to: px.count, by: 4) { sum += Double(px[i]) + Double(px[i + 1]) + Double(px[i + 2]) }
        return sum / Double(w * h * 3)
    }

    func testFirstLaunchAsksForAnExampleAndCanSkip() {
        let app = launch(["-ResetReferences", "YES"], language: "tr")
        XCTAssertTrue(app.staticTexts["Nasıl bir fotoğraf çekmek istiyorsun?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["pickReference"].exists)
        app.buttons["skipReference"].tap()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["referenceChip"].label.contains("Örnek seç"))
    }

    func testDarkExampleMakesThePreviewDarkerAndIsRemembered() {
        var app = launch(["-ResetReferences", "YES", "-ReferencePrompt", "NO"])
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        sleep(2)
        let plain = previewBrightness(app)
        app.terminate()

        app = launch(["-UITestReference", "03-moody-table.jpg"])
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        closeCard(app)
        XCTAssertTrue(app.buttons["referenceChip"].label.contains("example"))
        sleep(4) // a few matching rounds
        let matched = previewBrightness(app)
        XCTAssertLessThan(matched, plain - 8, "preview follows the darker example (plain \(plain), matched \(matched))")
        app.terminate()

        // Next launch opens straight into the camera with the same example (Hikâye 0.2), without the card (7.1).
        app = launch([])
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["pickReference"].exists)
        sleep(1)
        XCTAssertFalse(app.buttons["card.start"].exists, "the card does not open at launch")
        XCTAssertTrue(app.buttons["referenceChip"].label.contains("example"))
    }

    /// Icon → card → Örneklerim → pick → card again → shoot without an example (spec 05 Hikâye 0.2, 7.1, 7.2).
    func testExamplesSheetCanSwitchToNoExample() {
        let app = launch(["-ResetReferences", "YES", "-UITestReference", "01-morning-light.jpg"])
        XCTAssertTrue(app.buttons["referenceChip"].waitForExistence(timeout: 10))
        closeCard(app)
        app.buttons["referenceChip"].tap()
        XCTAssertTrue(app.buttons["card.change"].waitForExistence(timeout: 5), "the icon reopens the card")
        app.buttons["card.change"].tap()
        XCTAssertTrue(app.buttons["newReference"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "reference.item").count, 1)
        app.buttons.matching(identifier: "reference.item").firstMatch.tap()
        XCTAssertTrue(app.buttons["card.none"].waitForExistence(timeout: 5), "picking from the list opens the card")
        app.buttons["card.none"].tap()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["referenceChip"].label.contains("Choose"))
    }

    /// The card reads the example in plain sentences, in Turkish too, and hides the camera sentences (Hikâye 7).
    func testCardShowsTheReadingAndSteps() {
        let app = launch(["-ResetReferences", "YES", "-UITestReference", "03-moody-table.jpg"], language: "tr")
        XCTAssertTrue(app.staticTexts["Bu fotoğraf nasıl çekilmiş?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Böyle çek"].exists)
        // Brightness and color can always be read; lines that cannot be read are absent, not empty.
        XCTAssertTrue(app.descendants(matching: .any)["card.line.tone"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["card.line.color"].exists)
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any).matching(identifier: "card.step").count, 1)
        XCTAssertLessThanOrEqual(app.descendants(matching: .any).matching(identifier: "card.step").count, 3)
        XCTAssertFalse(app.descendants(matching: .any)["status"].exists)
        XCTAssertTrue(app.buttons["Çekime başla"].exists)
    }

    /// Hikâye 8: a photo with camera data shows its shutter speed and ISO; one without shows only the estimates.
    func testCardShowsTheExampleSettings() {
        var app = launch(["-ResetReferences", "YES", "-UITestReference", "02-coffee-break.jpg", "-UITestReferenceCameraData", "YES"], language: "tr")
        XCTAssertTrue(app.buttons["card.start"].waitForExistence(timeout: 10))
        app.swipeUp()
        let shutter = app.descendants(matching: .any)["settings.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        XCTAssertTrue(shutter.label.contains("1/125 sn"), shutter.label)
        XCTAssertTrue(app.descendants(matching: .any)["settings.iso"].label.contains("ISO 64"))
        XCTAssertTrue(app.descendants(matching: .any)["settings.brightness"].label.contains("EV"))
        XCTAssertFalse(app.descendants(matching: .any)["settings.noCameraData"].exists)
        app.terminate()

        app = launch(["-ResetReferences", "YES", "-UITestReference", "02-coffee-break.jpg"], language: "tr")
        XCTAssertTrue(app.buttons["card.start"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["settings.noCameraData"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["settings.shutter"].exists, "no made-up shutter speed")
        XCTAssertTrue(app.descendants(matching: .any)["settings.brightness"].exists)
    }

    func testCaptureWithAnExample() {
        let app = launch(["-ResetReferences", "YES", "-UITestReference", "02-coffee-break.jpg"])
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        closeCard(app)
        XCTAssertTrue(app.descendants(matching: .any)["ghost"].waitForExistence(timeout: 5), "example outline over the live view")
        sleep(2)
        app.buttons["shutter"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 2) {
            springboard.alerts.firstMatch.buttons.element(boundBy: springboard.alerts.firstMatch.buttons.count - 1).tap()
        }
        XCTAssertTrue(app.buttons["lastPhoto"].waitForExistence(timeout: 10))
        app.buttons["lastPhoto"].tap()
        XCTAssertTrue(app.images["reviewImage"].waitForExistence(timeout: 5))
    }
}
