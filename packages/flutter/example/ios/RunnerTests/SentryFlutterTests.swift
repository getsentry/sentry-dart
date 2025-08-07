//
//  RunnerTests.swift
//  RunnerTests
//
//  Created by Denis Andrašec on 07.08.23.
//

import XCTest
import sentry_flutter
import Sentry

// swiftlint:disable function_body_length line_length

final class SentryFlutterTests: XCTestCase {

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    func testUpdate() {
        let sut = fixture.getSut()

        sut.update(
            options: fixture.options,
            with: [
                "dsn": "https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562",
                "debug": true,
                "environment": "fixture-environment",
                "release": "fixture-release",
                "enableAutoSessionTracking": false,
                "attachStacktrace": false,
                "diagnosticLevel": "warning",
                "autoSessionTrackingIntervalMillis": NSNumber(value: 9001),
                "dist": "fixture-dist",
                "enableAutoNativeBreadcrumbs": false,
                "enableNativeCrashHandling": false,
                "maxBreadcrumbs": NSNumber(value: 9002),
                "sendDefaultPii": true,
                "maxCacheItems": NSNumber(value: 9003),
                "enableWatchdogTerminationTracking": false,
                "sendClientReports": false,
                "maxAttachmentSize": NSNumber(value: 9004),
                "captureFailedRequests": false,
                "enableAppHangTracking": false,
                "appHangTimeoutIntervalMillis": NSNumber(value: 10000),
                "proxy": [
                    "host": "localhost",
                    "port": NSNumber(value: 8080),
                    "type": "hTtP", // mixed case to check enum mapping
                    "user": "admin",
                    "pass": "0000"
                ]
            ]
        )

        XCTAssertEqual("https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562", fixture.options.dsn)
        XCTAssertEqual(true, fixture.options.debug)
        XCTAssertEqual("fixture-environment", fixture.options.environment)
        XCTAssertEqual("fixture-release", fixture.options.releaseName)
        XCTAssertEqual(false, fixture.options.enableAutoSessionTracking)
        XCTAssertEqual(false, fixture.options.attachStacktrace)
        XCTAssertEqual(SentryLevel.warning, fixture.options.diagnosticLevel)
        XCTAssertEqual(9001, fixture.options.sessionTrackingIntervalMillis)
        XCTAssertEqual("fixture-dist", fixture.options.dist)
        XCTAssertEqual(false, fixture.options.enableAutoBreadcrumbTracking)
        XCTAssertEqual(false, fixture.options.enableCrashHandler)
        XCTAssertEqual(false, fixture.options.enableCrashHandler)
        XCTAssertEqual(9002, fixture.options.maxBreadcrumbs)
        XCTAssertEqual(true, fixture.options.sendDefaultPii)
        XCTAssertEqual(9003, fixture.options.maxCacheItems)
        XCTAssertEqual(false, fixture.options.enableWatchdogTerminationTracking)
        XCTAssertEqual(false, fixture.options.sendClientReports)
        XCTAssertEqual(9004, fixture.options.maxAttachmentSize)
        XCTAssertEqual(false, fixture.options.enableCaptureFailedRequests)
        XCTAssertEqual(false, fixture.options.enableAppHangTracking)
        XCTAssertEqual(10, fixture.options.appHangTimeoutInterval)

        XCTAssertNotNil(fixture.options.urlSession)
        XCTAssertEqual(true, fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPEnable as String] as? Bool)
        XCTAssertEqual("localhost", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPProxy as String] as? String)
        XCTAssertEqual(8080, fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPPort as String] as? Int)
        XCTAssertEqual("admin", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFProxyUsernameKey as String] as? String)
        XCTAssertEqual("0000", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFProxyPasswordKey as String] as? String)
    }

    func testUpdateSocksProxy() {
        let sut = fixture.getSut()

        sut.update(
            options: fixture.options,
            with: [
                "proxy": [
                    "host": "localhost",
                    "port": 8080,
                    "type": "sOcKs", // mixed case to check enum mapping
                    "user": "admin",
                    "pass": "0000"
                ]
            ]
        )

        #if os(macOS)
        XCTAssertNotNil(fixture.options.urlSession)
        XCTAssertEqual(true, fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesSOCKSEnable as String] as? Bool)
        XCTAssertEqual("localhost", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesSOCKSProxy as String] as? String)
        XCTAssertEqual(8080, fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFNetworkProxiesSOCKSPort as String] as? Int)
        XCTAssertEqual("admin", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFProxyUsernameKey as String] as? String)
        XCTAssertEqual("0000", fixture.options.urlSession?.configuration.connectionProxyDictionary?[kCFProxyPasswordKey as String] as? String)
        #else
        XCTAssertNil(fixture.options.urlSession)
        #endif
    }
}

extension SentryFlutterTests {
    final class Fixture {

        var options = Options()

        func getSut() -> SentryFlutter {
            return SentryFlutter()
        }
    }
}

// swiftlint:enable function_body_length line_length
