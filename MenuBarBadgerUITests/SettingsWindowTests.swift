import XCTest

/// The settings window flows of docs/spec/testing.md. The app reads its badges from a fake Dock file, so the
/// tests need no Accessibility permission.
final class SettingsWindowTests: XCTestCase {
    private static let timeout: TimeInterval = 5

    private let folder = FileManager.default.temporaryDirectory.appending(path: "MenuBarBadgerUITests-\(UUID().uuidString)")
    private var configFile: URL { folder.appending(path: "config.json") }
    @MainActor private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: folder.appending(path: "dock.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    @MainActor
    func testAddAnAppWithTheKeyboard() throws {
        try launch(apps: [])
        element("addApp").click()
        let results = element("appResults")
        XCTAssertTrue(results.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(results.staticTexts["TextEdit"].waitForExistence(timeout: Self.timeout))

        app.typeText("TextEdit")
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(results.waitForNonExistence(timeout: Self.timeout))
        waitForConfig { $0 == ["com.apple.TextEdit"] }
        XCTAssertTrue(element("openApp").waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(rows().count, 1)
        XCTAssertEqual(element("openApp").label, "Open TextEdit")
    }

    @MainActor
    func testRemoveWithMinusDeleteKeyAndContextMenu() throws {
        try launch(apps: ["com.apple.TextEdit", "com.apple.calculator", "com.apple.Preview"])
        let remove = element("removeApp")
        XCTAssertTrue(remove.waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(remove.isEnabled)

        rows().element(boundBy: 0).click()
        XCTAssertTrue(remove.isEnabled)
        remove.click()
        waitForConfig { $0 == ["com.apple.calculator", "com.apple.Preview"] }
        XCTAssertFalse(remove.isEnabled)

        rows().element(boundBy: 0).click()
        app.typeKey(.delete, modifierFlags: [])
        waitForConfig { $0 == ["com.apple.Preview"] }

        rows().element(boundBy: 0).rightClick()
        app.menuItems["Remove"].click()
        waitForConfig { $0.isEmpty }
        XCTAssertEqual(rows().count, 0)
    }

    @MainActor
    func testSelectionStaysAfterASettingChange() throws {
        try launch(apps: ["com.apple.TextEdit", "com.apple.calculator"])
        rows().element(boundBy: 1).click()
        let openApp = element("openApp")
        XCTAssertTrue(openApp.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(openApp.label, "Open Calculator")

        element("appIconMode").radioButtons["Monochrome"].click()

        let iconModes = try XCTUnwrap(waitForConfigApps { $0.last?["icon"] as? String == "monochrome" })
        XCTAssertEqual(iconModes.first?["icon"] as? String, "color")
        XCTAssertEqual(openApp.label, "Open Calculator")
        XCTAssertTrue(element("removeApp").isEnabled)
    }

    /// The fake Dock source grants the permission, so Done is enabled at once.
    @MainActor
    func testSetupScreenAtTheFirstLaunchThenTheAddSheetWithTheChosenIcon() throws {
        start(skipsSetup: false)
        XCTAssertTrue(element("setupScreen").waitForExistence(timeout: Self.timeout), "The setup screen did not open")
        XCTAssertFalse(element("settingsTabs").exists)
        XCTAssertFalse(element("appsList").exists)

        element("setupIconMode").radioButtons["Monochrome"].click()
        let done = element("setupDone")
        XCTAssertTrue(done.waitForEnabled(timeout: Self.timeout))
        done.click()
        let results = element("appResults")
        XCTAssertTrue(results.waitForExistence(timeout: Self.timeout), "The add sheet did not open")
        XCTAssertTrue(element("settingsTabs").exists)
        XCTAssertTrue(results.staticTexts["TextEdit"].waitForExistence(timeout: Self.timeout))
        app.typeText("TextEdit")
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertNotNil(waitForConfigApps { $0.first?["icon"] as? String == "monochrome" })

        app.terminate()
        start(skipsSetup: false)
        XCTAssertTrue(element("appsList").waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(element("setupScreen").exists)
    }

    @MainActor
    func testConfigErrorBannerShowsForABadFileAndGoesAwayAfterAFix() throws {
        try launch(apps: ["com.apple.TextEdit"])
        let banner = element("configErrorBanner")
        XCTAssertTrue(element("appsList").waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(banner.exists)

        try Data("{ \"version\": 1, ".utf8).write(to: configFile)
        XCTAssertTrue(banner.waitForExistence(timeout: Self.timeout))

        try writeConfig(apps: ["com.apple.TextEdit"])
        XCTAssertTrue(banner.waitForNonExistence(timeout: Self.timeout))
        XCTAssertEqual(rows().count, 1)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(apps: [String]) throws {
        try writeConfig(apps: apps)
        start(skipsSetup: true)
        XCTAssertTrue(element("appsList").waitForExistence(timeout: Self.timeout), "The settings window did not open")
    }

    /// With no config file and `skipsSetup` false, the launch is a first launch.
    @MainActor
    private func start(skipsSetup: Bool) {
        app = XCUIApplication()
        app.launchArguments = [
            "-MBBFakeDock", folder.appending(path: "dock.json").path,
            "-MBBConfigFile", configFile.path,
            "-MBBSkipSetup", skipsSetup ? "YES" : "NO",
            "-SettingsLastTab", "0",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        addTeardownBlock { @MainActor [app] in app?.terminate() }
        // The launch does not activate an agent app. The first activation opens the settings window.
        app.activate()
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func rows() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "appRow")
    }

    private func writeConfig(apps: [String]) throws {
        let config: [String: Any] = ["version": 1, "apps": apps.map { ["bundleID": $0] }]
        try JSONSerialization.data(withJSONObject: config).write(to: configFile, options: .atomic)
    }

    private func configApps() -> [[String: Any]]? {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return config["apps"] as? [[String: Any]]
    }

    @discardableResult
    private func waitForConfigApps(_ condition: ([[String: Any]]) -> Bool) -> [[String: Any]]? {
        let deadline = Date.now.addingTimeInterval(Self.timeout)
        while Date.now < deadline {
            if let apps = configApps(), condition(apps) { return apps }
            RunLoop.current.run(until: .now.addingTimeInterval(0.1))
        }
        return nil
    }

    private func waitForConfig(_ condition: ([String]) -> Bool) {
        let apps = waitForConfigApps { condition($0.compactMap { $0["bundleID"] as? String }) }
        XCTAssertNotNil(apps, "The config file has the apps \(configApps()?.compactMap { $0["bundleID"] } ?? [])")
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
