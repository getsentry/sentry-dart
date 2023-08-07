package io.sentry.flutter

import io.sentry.android.core.SentryAndroidOptions
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class SentryFlutterTest {

  private lateinit var fixture: Fixture

  @Before
  fun before() {
    fixture = Fixture()
  }

  @Test
  fun initNativeSkd() {
    val sut = fixture.getSut();
    sut.initNativeSdk(mapOf(
      "dsn" to "fixture-dsn"
    ))
    assertEquals("fixture-dsn", fixture.options.dsn)
  }
}

class Fixture {

  var options = SentryAndroidOptions()

  fun getSut(): SentryFlutter {
    return SentryFlutter(options = options)
  }

}
