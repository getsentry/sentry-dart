package io.sentry.flutter

import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ScreenshotRecorderCallback
import io.sentry.android.replay.ReplayIntegration

object SentryFlutterReplay {
  // Set by the Flutter side, read during SentryAndroid.init()
  lateinit var recorder: Recorder

  // Set by SentryAndroid.init(), read by the Flutter side in recorder.start()
  lateinit var integration: ReplayIntegration
}
