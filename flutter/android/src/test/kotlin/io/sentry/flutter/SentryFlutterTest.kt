package io.sentry.flutter

import io.sentry.SentryLevel
import io.sentry.android.core.BuildConfig
import io.sentry.android.core.SentryAndroidOptions
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.net.Proxy

class SentryFlutterTest {
  private lateinit var fixture: Fixture

  @Before
  fun before() {
    fixture = Fixture()
  }

  @Test
  fun updateOptions() {
    // Given
    val sut = fixture.getSut()

    // When
    sut.updateOptions(fixture.options, fixture.data)

    // Then
    assertEquals("fixture-dsn", fixture.options.dsn)
    assertEquals(true, fixture.options.isDebug)
    assertEquals("fixture-environment", fixture.options.environment)
    assertEquals("fixture-release", fixture.options.release)
    assertEquals("fixture-dist", fixture.options.dist)
    assertEquals(false, fixture.options.isEnableAutoSessionTracking)
    assertEquals(9001L, fixture.options.sessionTrackingIntervalMillis)
    assertEquals(9002L, fixture.options.anrTimeoutIntervalMillis)
    assertEquals(true, fixture.options.isAttachThreads)
    assertEquals(false, fixture.options.isAttachStacktrace)
    assertEquals(false, fixture.options.isEnableActivityLifecycleBreadcrumbs)
    assertEquals(false, fixture.options.isEnableAppLifecycleBreadcrumbs)
    assertEquals(false, fixture.options.isEnableSystemEventBreadcrumbs)
    assertEquals(false, fixture.options.isEnableAppComponentBreadcrumbs)
    assertEquals(false, fixture.options.isEnableUserInteractionBreadcrumbs)
    assertEquals(9003, fixture.options.maxBreadcrumbs)
    assertEquals(9004, fixture.options.maxCacheItems)
    assertEquals(false, fixture.options.isAnrEnabled)
    assertEquals(true, fixture.options.isSendDefaultPii)
    assertEquals(false, fixture.options.isEnableScopeSync)
    assertEquals("fixture-proguardUuid", fixture.options.proguardUuid)
    assertEquals(false, fixture.options.isSendClientReports)
    assertEquals(9005L, fixture.options.maxAttachmentSize)

    assertEquals("sentry.java.android.flutter", fixture.options.sdkVersion?.name)
    assertEquals(BuildConfig.VERSION_NAME, fixture.options.sdkVersion?.version)
    assertEquals(
      "sentry.java.android.flutter/${BuildConfig.VERSION_NAME}",
      fixture.options.sentryClientName,
    )
    assertEquals("fixture-nativeSdk", fixture.options.nativeSdkName)

    assertEquals(true, sut.autoPerformanceTracingEnabled)

    assertEquals(9006, fixture.options.connectionTimeoutMillis)
    assertEquals(9007, fixture.options.readTimeoutMillis)

    assertEquals("localhost", fixture.options.proxy?.host)
    assertEquals("8080", fixture.options.proxy?.port)
    assertEquals(Proxy.Type.HTTP, fixture.options.proxy?.type)
    assertEquals("admin", fixture.options.proxy?.user)
    assertEquals("0000", fixture.options.proxy?.pass)

    assertEquals(0.5, fixture.options.experimental.sessionReplay.sessionSampleRate)
    assertEquals(0.6, fixture.options.experimental.sessionReplay.onErrorSampleRate)

    // Note: these are currently read-only in SentryReplayOptions so we're only asserting the default values here to
    // know when there's a change in the native SDK, as it may require a manual change in the Flutter implementation.
    assertEquals(1, fixture.options.experimental.sessionReplay.frameRate)
    assertEquals(30_000L, fixture.options.experimental.sessionReplay.errorReplayDuration)
    assertEquals(5000L, fixture.options.experimental.sessionReplay.sessionSegmentDuration)
    assertEquals(60 * 60 * 1000L, fixture.options.experimental.sessionReplay.sessionDuration)
  }

  @Test
  fun initNativeSdkDiagnosticLevel() {
    // Given
    val sut = fixture.getSut()
    fixture.options.isDebug = true

    // When
    sut.updateOptions(
      fixture.options,
      mapOf(
        "diagnosticLevel" to "warning",
      ),
    )

    // Then
    assertEquals(SentryLevel.WARNING, fixture.options.diagnosticLevel)
  }

  @Test
  fun initNativeSdkEnableNativeCrashHandling() {
    // Given
    val sut = fixture.getSut()

    // When
    sut.updateOptions(
      fixture.options,
      mapOf(
        "enableNativeCrashHandling" to false,
      ),
    )

    // Then
    assertEquals(false, fixture.options.isEnableUncaughtExceptionHandler)
    assertEquals(false, fixture.options.isAnrEnabled)
  }
}

class Fixture {
  var options = SentryAndroidOptions()

  val data =
    mapOf(
      "dsn" to "fixture-dsn",
      "debug" to true,
      "environment" to "fixture-environment",
      "release" to "fixture-release",
      "dist" to "fixture-dist",
      "enableAutoSessionTracking" to false,
      "autoSessionTrackingIntervalMillis" to 9001L,
      "anrTimeoutIntervalMillis" to 9002L,
      "attachThreads" to true,
      "attachStacktrace" to false,
      "enableAutoNativeBreadcrumbs" to false,
      "maxBreadcrumbs" to 9003,
      "maxCacheItems" to 9004,
      "anrEnabled" to false,
      "sendDefaultPii" to true,
      "enableNdkScopeSync" to false,
      "proguardUuid" to "fixture-proguardUuid",
      "enableNativeCrashHandling" to false,
      "sendClientReports" to false,
      "maxAttachmentSize" to 9005L,
      "enableAutoPerformanceTracing" to true,
      "connectionTimeoutMillis" to 9006,
      "readTimeoutMillis" to 9007,
      "proxy" to
        mapOf(
          "host" to "localhost",
          "port" to 8080,
          "type" to "http", // lowercase to check enum mapping
          "user" to "admin",
          "pass" to "0000",
        ),
      "replay" to
        mapOf(
          "sessionSampleRate" to 0.5,
          "onErrorSampleRate" to 0.6,
        ),
    )

  fun getSut(): SentryFlutter =
    SentryFlutter(
      androidSdk = "sentry.java.android.flutter",
      nativeSdk = "fixture-nativeSdk",
    )
}
