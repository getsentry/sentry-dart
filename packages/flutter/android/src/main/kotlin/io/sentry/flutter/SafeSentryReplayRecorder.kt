//package io.sentry.flutter
//
//import io.sentry.android.replay.Recorder
//import io.sentry.android.replay.ReplayIntegration
//import io.sentry.android.replay.ScreenshotRecorderConfig
//
//internal class SafeSentryReplayRecorder(
//  replayCallbacks: ReplayRecorderCallbacks,
//  integration: ReplayIntegration,
//) : Recorder {
//  private val delegate =
//    SentryFlutterReplayRecorder(
//      SafeReplayRecorderCallbacks(replayCallbacks),
//      integration,
//    )
//
//  override fun start() {
//    delegate.start()
//  }
//
//  override fun resume() {
//    delegate.resume()
//  }
//
//  override fun onConfigurationChanged(config: ScreenshotRecorderConfig) {
//    delegate.onConfigurationChanged(config)
//  }
//
//  override fun reset() {
//    delegate.reset()
//  }
//
//  override fun pause() {
//    delegate.pause()
//  }
//
//  override fun stop() {
//    delegate.stop()
//  }
//
//  override fun close() {
//    delegate.close()
//  }
//}
//
//
