//
//  CalmCourierUITests.swift
//  CalmCourierUITests
//
//  Created by Sarah Clark on 11/5/26.
//

import XCTest

@MainActor
final class CalmCourierUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// Runs an accessibility audit and fails with the element and issue details for each finding.
    @MainActor
    private func audit(file: StaticString = #filePath, line: UInt = #line) throws {
        // Report every finding, not just the first.
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType) '\($0.label)' id '\($0.identifier)'" } ?? "unknown element"
            XCTFail("\(issue.compactDescription): \(element). \(issue.detailedDescription)", file: file, line: line)
            return true
        }
    }

    @MainActor
    func testBrowseAddToCartAndCheckout() throws {
        app.buttons["restaurant-harbor-noodle"].tap()
        app.buttons["add-hn-ramen"].tap()
        app.buttons["view-cart-button"].tap()

        XCTAssertTrue(app.navigationBars["Cart"].waitForExistence(timeout: 5))
        app.buttons["checkout-button"].tap()
        app.buttons["pay-button"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["order-confirmation"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDebugPanelInjectionShowsNeutralOffer() throws {
        app.buttons["debug-panel-button"].tap()
        let injectRageTap = app.buttons["inject-rageTap"]
        for _ in 0..<5 where !injectRageTap.isHittable {
            app.swipeUp()
        }
        injectRageTap.tap()
        app.buttons["inject-rageTap"].tap()
        app.buttons["inject-checkoutFailure"].tap()
        app.buttons["debug-done-button"].tap()

        // The tier changes only after the score stays past the threshold for 3 seconds.
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Here's a deal on us"))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
    }

    @MainActor
    func testAccessibilityAuditRestaurantList() throws {
        try audit()
    }

    @MainActor
    func testAccessibilityAuditMenuAndCart() throws {
        app.buttons["restaurant-harbor-noodle"].tap()
        app.buttons["add-hn-ramen"].tap()
        try audit()

        app.buttons["view-cart-button"].tap()
        XCTAssertTrue(app.navigationBars["Cart"].waitForExistence(timeout: 5))
        try audit()

        app.buttons["checkout-button"].tap()
        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        try audit()
    }

    @MainActor
    func testAccessibilityAuditDebugPanel() throws {
        app.buttons["debug-panel-button"].tap()
        XCTAssertTrue(app.buttons["debug-done-button"].waitForExistence(timeout: 5))
        try audit()
    }
}
