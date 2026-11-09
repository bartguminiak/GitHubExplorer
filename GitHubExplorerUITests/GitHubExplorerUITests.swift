import XCTest
import XCUIAutomation

final class GitHubExplorerUITests: XCTestCase {
    @MainActor
    func testRetryRecoversSearchAndDetailWithoutChangingInput() {
        let app = XCUIApplication(bundleIdentifier: "com.bartlomiejguminiakpersonalteam.GitHubExplorer")
        app.launchArguments = ["--test-retry-recovery"]
        app.launch()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("swift")

        let searchRetry = app.buttons["searchRetry"]
        XCTAssertTrue(searchRetry.waitForExistence(timeout: 5))
        searchRetry.tap()

        let result = app.staticTexts["apple/swift"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "swift")
        result.tap()

        let detailRetry = app.buttons["detailRetry"]
        XCTAssertTrue(detailRetry.waitForExistence(timeout: 5))
        detailRetry.tap()
        XCTAssertTrue(app.staticTexts["Full name"].waitForExistence(timeout: 5))
        XCTAssertFalse(detailRetry.exists)
    }
}
