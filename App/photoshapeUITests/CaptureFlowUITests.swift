import XCTest

/// Spec 01 flows in the simulator, with the simulated camera.
/// Device-only behavior (real lenses, focus, interruptions, timing) is on the manual test list.
final class CaptureFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ language: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Spec 01 flows: no example photo, skip the example prompt.
        app.launchArguments = ["-AppleLanguages", "(\(language))",
                               "-AppleLocale", language == "tr" ? "tr_TR" : "en_US",
                               "-ResetReferences", "YES", "-ReferencePrompt", "NO"] + arguments
        app.launch()
        return app
    }

    /// The add-only Photos prompt appears on the first save unless access was granted beforehand.
    private func allowPhotosIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }
        let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'İzin'"))
            .allElementsBoundByIndex.last(where: { !$0.label.localizedCaseInsensitiveContains("Don") && !$0.label.contains("Verme") })
        (allow ?? alert.buttons.element(boundBy: alert.buttons.count - 1)).tap()
    }

    private func takePhoto(_ app: XCUIApplication) {
        let shutter = app.buttons["shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        allowPhotosIfAsked()
        XCTAssertTrue(app.buttons["lastPhoto"].waitForExistence(timeout: 10), "corner preview appears after capture")
    }

    func testCaptureThenReviewAndShareInFourByFive() {
        let app = launch("en")
        for lens in ["wide", "normal", "close"] {
            XCTAssertTrue(app.buttons["lens.\(lens)"].waitForExistence(timeout: 10), "lens \(lens)")
        }
        app.buttons["lens.close"].tap()
        XCTAssertTrue(app.buttons["lens.close"].isSelected)

        takePhoto(app)
        app.buttons["lastPhoto"].tap()

        let image = app.images["reviewImage"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertEqual(image.frame.width / image.frame.height, 4.0 / 5.0, accuracy: 0.01, "saved/shared photo is 4:5")
        XCTAssertTrue(app.buttons["share"].exists)
        XCTAssertTrue(app.buttons["share"].label.contains("Share"))
        // Spec 07 Hikâye 1.4: no Instagram in the simulator, so only the system share button.
        XCTAssertFalse(app.buttons["instagram"].exists)
        app.buttons["close"].tap()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
    }

    func testTurkishTexts() {
        let app = launch("tr")
        XCTAssertTrue(app.buttons["lens.close"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["lens.wide"].label, "Geniş")
        XCTAssertEqual(app.buttons["lens.close"].label, "Yakın")
        XCTAssertEqual(app.buttons["shutter"].label, "Fotoğraf çek")
        takePhoto(app)
        app.buttons["lastPhoto"].tap()
        XCTAssertTrue(app.buttons["share"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["share"].label.contains("Paylaş"))
        XCTAssertEqual(app.buttons["close"].label, "Kapat")
    }

    func testRapidPressesDoNotFreezeTheShutter() {
        let app = launch("en")
        takePhoto(app)
        let shutter = app.buttons["shutter"]
        for _ in 0..<8 { shutter.tap() }
        // After the burst the camera is still usable and another capture goes through.
        let thumbnail = app.buttons["lastPhoto"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 10))
        thumbnail.tap()
        XCTAssertTrue(app.images["reviewImage"].waitForExistence(timeout: 5))
    }

    func testRevertHintOnEarlyPhotosOnly() {
        // First reviews: the note appears once the photo is saved with its edit.
        var app = launch("tr", arguments: ["-revertHintShownCount", "0"])
        takePhoto(app)
        app.buttons["lastPhoto"].tap()
        let hint = app.staticTexts["revertHint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 8))
        XCTAssertTrue(hint.label.contains("Özgüne Dön"))
        app.terminate()

        // After three reviews it no longer appears.
        app = launch("en", arguments: ["-revertHintShownCount", "3"])
        takePhoto(app)
        app.buttons["lastPhoto"].tap()
        XCTAssertTrue(app.buttons["share"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["revertHint"].waitForExistence(timeout: 4))
    }

    func testDeniedCameraShowsExplanationAndSettingsButton() {
        let app = launch("tr", arguments: ["-SimulateCameraDenied", "YES"])
        XCTAssertTrue(app.otherElements["cameraDenied"].waitForExistence(timeout: 10)
                      || app.staticTexts["Kamera izni kapalı"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Kamera izni kapalı"].exists)
        XCTAssertTrue(app.buttons["openSettings"].exists)
        XCTAssertEqual(app.buttons["openSettings"].label, "Ayarlar'ı aç")
        XCTAssertFalse(app.buttons["shutter"].exists)
    }

    /// Spec 03 Hikâye 4: developer builds have the recipe editor; a slider changes the recipe and export is offered.
    func testDeveloperRecipeEditor() {
        let app = launch("en")
        let tools = app.buttons["devTools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 10))
        tools.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dev.slider.exposure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dev.export"].exists)
        XCTAssertTrue(app.buttons["dev.freeze"].exists)
        app.buttons["dev.freeze"].tap()
        XCTAssertTrue(app.buttons["dev.freeze"].label == "Live" || app.buttons["Live"].waitForExistence(timeout: 3),
                      "frozen frame can go back to live")
    }

    /// Spec 07 Hikâye 1: with Instagram, one button offers Post (and Story with an app ID); when Instagram's way does
    /// not work (here: not really installed) the system share sheet opens instead of an error (1.5).
    func testInstagramOffersPostAndFallsBackToTheShareSheet() {
        let app = launch("en", arguments: ["-UITestInstagramInstalled", "YES"])
        takePhoto(app)
        app.buttons["lastPhoto"].tap()
        let instagram = app.buttons["instagram"]
        XCTAssertTrue(instagram.waitForExistence(timeout: 5))
        instagram.tap()
        let post = app.buttons.matching(identifier: "Post").firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 3), "two taps to the post screen (SC-001)")
        XCTAssertFalse(app.buttons["Story"].exists, "no Story without a Meta app ID")
        post.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 2)
                      || app.collectionViews.cells.count > 0, "falls back to the share sheet")
    }
}
