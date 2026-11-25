//
//  SiriActionsUITests.swift
//  TalkMVPSiriUITests
//
//  The Siri and Shortcuts actions, run through the system against the app
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import AppIntentsTesting
import XCTest

final class SiriActionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Sends a message and summarizes a chat the way Siri would, through AppIntentsTesting,
    /// against the running app signed into test mode.
    @MainActor
    func testSiriSendsAMessageAndSummarizesAChat() async throws {
        let app = launchInTestModeOnChats()

        let definitions = IntentDefinitions(bundleIdentifier: "com.cclab.TalkMVP.TalkMVP")
        let matches = try await afterTheSystemKnowsTheApp {
            try await definitions.entities["ChatConversationEntity"].entities(matching: "Family")
        }
        let family = try XCTUnwrap(matches.first, "Siri finds the chat by part of its name")

        try await definitions.intents["SendChatMessageIntent"].makeIntent(chat: family, message: "Sent from Siri").run()

        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sent from Siri"].firstMatch.waitForExistence(timeout: 5), "the message shows up in the chat")

        let result = try await definitions.intents["SummarizeChatIntent"].makeIntent(chat: family).run()
        let summary: String = try result.value
        XCTAssertFalse(summary.isEmpty)
        print("SIRI-SUMMARY \(summary.replacingOccurrences(of: "\n", with: " / "))")
    }

    /// Edit in L!NK on Siri's reply card: the chat opens with the reply in its message field,
    /// and nothing is sent.
    @MainActor
    func testEditInLinkOpensTheChatWithTheDraft() async throws {
        let app = launchInTestModeOnChats()

        let definitions = IntentDefinitions(bundleIdentifier: "com.cclab.TalkMVP.TalkMVP")
        let matches = try await afterTheSystemKnowsTheApp {
            try await definitions.entities["ChatConversationEntity"].entities(matching: "Family Trip")
        }
        let trip = try XCTUnwrap(matches.first, "Siri finds the chat by its name")

        try await definitions.intents["OpenChatDraftIntent"].makeIntent(chat: trip, text: "Draft from Siri").run()

        let field = app.textFields["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the chat opens")
        XCTAssertEqual(field.value as? String, "Draft from Siri", "the draft is in the message field")
        XCTAssertFalse(app.staticTexts["Draft from Siri"].exists, "the draft isn't sent")
    }

    /// Launches the app with an empty store, starts test mode and opens the Chats tab.
    @MainActor
    private func launchInTestModeOnChats() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryStore", "-selectedLanguage", "en", "-contactsOnboardingShown", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["testModeButton"].waitForExistence(timeout: 10))
        app.buttons["testModeButton"].tap()
        let startTest = app.buttons["Start Test"].firstMatch
        XCTAssertTrue(startTest.waitForExistence(timeout: 5))
        startTest.tap()
        XCTAssertTrue(app.buttons["Chats"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Chats"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Family Group"].firstMatch.waitForExistence(timeout: 5))
        return app
    }

    /// Runs `query` once the system has read the app's App Intents. That happens shortly after
    /// the app is installed, so on a fresh simulator (or the clone a parallel test run uses) the
    /// first query can come too early and fail with "com.cclab.TalkMVP.TalkMVP is not present".
    private func afterTheSystemKnowsTheApp<T>(_ query: () async throws -> T) async throws -> T {
        let deadline = ContinuousClock.now + .seconds(60)
        while true {
            do {
                return try await query()
            } catch let error as NSError where error.domain == "AppIntentsServicesMetadataErrorDomain" && ContinuousClock.now < deadline {
                try await Task.sleep(for: .seconds(2))
            }
        }
    }
}
