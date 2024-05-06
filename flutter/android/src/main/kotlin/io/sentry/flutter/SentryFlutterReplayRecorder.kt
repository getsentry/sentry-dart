package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorder(
  private val channel: MethodChannel,
  private val cacheDirPath: String,
) : Recorder {
  override fun start(config: ScreenshotRecorderConfig) {
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
