package io.sentry.flutter

import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration

object SentryFlutterReplay {
  // Set by the Flutter side, read during SentryAndroid.init(). If null, replay is disabled.
  @JvmField
  var recorder: Recorder? = null

  // Set by SentryAndroid.init(), read by the Flutter side in recorder.start()
  lateinit var integration: ReplayIntegration
}
