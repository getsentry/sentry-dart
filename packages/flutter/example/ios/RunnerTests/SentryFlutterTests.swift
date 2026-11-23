//
//  RunnerTests.swift
//  RunnerTests
//
//  Created by Denis Andrašec on 07.08.23.
//

import XCTest
import sentry_flutter
@_spi(Private) import Sentry

// With Swift Package Manager the ObjC sources live in a separate module; with
// CocoaPods they are part of `sentry_flutter`. `SWIFT_PACKAGE` is not defined
// for this Xcode test target, so probe for the module instead.
#if canImport(sentry_flutter_objc)
import sentry_flutter_objc
#endif
#if os(iOS)
import UIKit
#endif

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
        "sampleRate": NSNumber(value: 0.25),
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
    XCTAssertEqual(0.25, fixture.options.sampleRate?.doubleValue)
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

  func testUpdateEnablesLogsAndMetrics() {
    let sut = fixture.getSut()

    sut.update(options: fixture.options, with: [:])

    XCTAssertEqual(true, fixture.options.enableLogs)
    XCTAssertEqual(true, fixture.options.enableMetrics)
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

  #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
  func testUpdateDoesNotSetNativeReplayNetworkDetailOptions() {
    // Setting these on sentry-cocoa would enable its own URLSession capture.
    let sut = fixture.getSut()

    sut.update(
      options: fixture.options,
      with: [
        "replay": [
          "networkDetailAllowUrls": ["api.example.com"],
          "networkCaptureBodies": false
        ]
      ]
    )

    let replay = fixture.options.sessionReplay
    XCTAssertTrue(replay.networkDetailAllowUrls.isEmpty)
    XCTAssertTrue(replay.networkCaptureBodies)
  }

  func testAttachReplayNetworkDetailKeepsDetailsOutOfSerializedBreadcrumb() throws {
    let breadcrumb = Breadcrumb(level: .info, category: "http")
    breadcrumb.data = ["url": "https://api.example.com/x"]

    SentryFlutterPlugin.attachReplayNetworkDetail(
      ["request": ["body": "req"]],
      to: breadcrumb
    )

    let stored = try XCTUnwrap(
      breadcrumb.data?[SentryFlutterReplayNetworkDetailsKey] as? [String: Any]
    )
    XCTAssertEqual("req", (stored["request"] as? [String: Any])?["body"] as? String)
    let serializedData = try XCTUnwrap(breadcrumb.serialize()["data"] as? [String: Any])
    XCTAssertEqual("https://api.example.com/x", serializedData["url"] as? String)
    XCTAssertNil(serializedData[SentryFlutterReplayNetworkDetailsKey])
  }

  func testAttachReplayNetworkDetailDropsDetailsFromBreadcrumbData() {
    let breadcrumb = Breadcrumb(level: .info, category: "http")
    breadcrumb.data = [SentryFlutterReplayNetworkDetailsKey: ["request": ["body": "forged"]]]

    SentryFlutterPlugin.attachReplayNetworkDetail(nil, to: breadcrumb)

    XCTAssertNil(breadcrumb.data?[SentryFlutterReplayNetworkDetailsKey])
  }

  func testReplayConverterForwardsNetworkDetails() throws {
    let event = try convertHttpBreadcrumb(extra: [
      SentryFlutterReplayNetworkDetailsKey: [
        "request": ["headers": ["foo": "bar"], "body": "req"],
        "response": ["headers": ["x-res": "1"], "body": "res"]
      ]
    ])

    let data = try spanData(of: event)
    XCTAssertEqual("req", (data["request"] as? [String: Any])?["body"] as? String)
    XCTAssertEqual("res", (data["response"] as? [String: Any])?["body"] as? String)
    XCTAssertEqual(200, data["statusCode"] as? Int)
  }

  func testReplayConverterIgnoresRequestAndResponseBreadcrumbData() throws {
    let event = try convertHttpBreadcrumb(extra: [
      "request": ["headers": ["Authorization": "Bearer secret"]],
      "response": ["body": "res"]
    ])

    let data = try spanData(of: event)
    XCTAssertNil(data["request"])
    XCTAssertNil(data["response"])
  }

  func testReplayConverterOmitsNetworkDetailsWhenNotDictionaries() throws {
    let event = try convertHttpBreadcrumb(extra: [
      SentryFlutterReplayNetworkDetailsKey: ["request": "oops", "response": 1]
    ])

    let data = try spanData(of: event)
    XCTAssertNil(data["request"])
    XCTAssertNil(data["response"])
  }

  private func spanData(of event: SentryRRWebEvent) throws -> [String: Any] {
    let payload = try XCTUnwrap(event.data?["payload"] as? [String: Any])
    return try XCTUnwrap(payload["data"] as? [String: Any])
  }

  private func convertHttpBreadcrumb(extra: [String: Any]) throws -> SentryRRWebEvent {
    let breadcrumb = Breadcrumb(level: .info, category: "http")
    var data: [String: Any] = [
      "url": "https://api.example.com/x",
      "method": "POST",
      "status_code": 200,
      "start_timestamp": 1_700_000_000_000,
      "end_timestamp": 1_700_000_001_000
    ]
    data.merge(extra) { _, new in new }
    breadcrumb.data = data

    let converter = SentryFlutterReplayBreadcrumbConverter()
    return try XCTUnwrap(converter.convert(from: breadcrumb) as? SentryRRWebEvent)
  }
  #endif

  #if os(iOS)
  func testFallbackDisplayRefreshRateOnIPhoneWithoutHighRefreshRateKeyCapsAt60() {
    let refreshRate = SentryFlutter.fallbackDisplayRefreshRate(
      maximumFramesPerSecond: 120,
      hardwareModel: "iPhone16,1",
      sceneRole: .windowApplication,
      infoDictionary: [:]
    )

    XCTAssertEqual(60, refreshRate)
  }

  func testFallbackDisplayRefreshRateOnIPhoneWithHighRefreshRateKeyFalseCapsAt60() {
    let refreshRate = SentryFlutter.fallbackDisplayRefreshRate(
      maximumFramesPerSecond: 120,
      hardwareModel: "iPhone16,1",
      sceneRole: .windowApplication,
      infoDictionary: ["CADisableMinimumFrameDurationOnPhone": NSNumber(value: false)]
    )

    XCTAssertEqual(60, refreshRate)
  }

  func testFallbackDisplayRefreshRateOnIPhoneWithHighRefreshRateKeyTrueReturnsMaximum() {
    let refreshRate = SentryFlutter.fallbackDisplayRefreshRate(
      maximumFramesPerSecond: 120,
      hardwareModel: "iPhone16,1",
      sceneRole: .windowApplication,
      infoDictionary: ["CADisableMinimumFrameDurationOnPhone": NSNumber(value: true)]
    )

    XCTAssertEqual(120, refreshRate)
  }

  func testFallbackDisplayRefreshRateOnIPhoneWithHighRefreshRateKeyStringYesReturnsMaximum() {
    let refreshRate = SentryFlutter.fallbackDisplayRefreshRate(
      maximumFramesPerSecond: 120,
      hardwareModel: "iPhone16,1",
      sceneRole: .windowApplication,
      infoDictionary: ["CADisableMinimumFrameDurationOnPhone": NSString(string: "YES")]
    )

    XCTAssertEqual(120, refreshRate)
  }

  func testFallbackDisplayRefreshRateForIPhoneOnlyAppOnIPadWithoutHighRefreshRateKeyReturnsMaximum() {
    let refreshRate = SentryFlutter.fallbackDisplayRefreshRate(
      maximumFramesPerSecond: 120,
      hardwareModel: "iPad14,5",
      sceneRole: .windowApplication,
      infoDictionary: [:]
    )

    XCTAssertEqual(120, refreshRate)
  }
  #endif
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
