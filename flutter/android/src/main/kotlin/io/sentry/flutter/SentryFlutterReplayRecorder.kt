package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig

// TODO try, catch, and log errors, otherwise the app will crash
internal class SentryFlutterReplayRecorder(
  private val channel: MethodChannel,
  private val integration: ReplayIntegration,
) : Recorder {
  override fun start(config: ScreenshotRecorderConfig) {
    val cacheDirPath = integration.replayCacheDir?.absolutePath
    if (cacheDirPath == null) {
      // TODO debug log
      return
    }
    Handler(Looper.getMainLooper()).post {
      channel.invokeMethod(
        "ReplayRecorder.start",
        mapOf(
          "directory" to cacheDirPath,
          "width" to config.recordingWidth,
          "height" to config.recordingHeight,
          "frameRate" to config.frameRate,
        ),
      )
    }
  }

  override fun resume() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("ReplayRecorder.resume", null) }
  }

  override fun pause() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("ReplayRecorder.pause", null) }
  }

  override fun stop() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("ReplayRecorder.stop", null) }
  }

  override fun close() {
    stop()
  }
}
