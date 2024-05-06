package io.sentry.flutter

import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.MethodChannel
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorder(
    private val channel: MethodChannel,
    private val cacheDirPath: String
) : Recorder {
  override fun start(recorderConfig: ScreenshotRecorderConfig) {
    Handler(Looper.getMainLooper()).post {
      channel.invokeMethod(
          "start",
          mapOf(
              "directory" to cacheDirPath,
              "width" to recorderConfig.recordingWidth,
              "height" to recorderConfig.recordingHeight,
              "frameRate" to recorderConfig.frameRate))
    }
  }

  override fun resume() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("resume", null) }
  }

  override fun pause() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("pause", null) }
  }

  override fun stop() {
    Handler(Looper.getMainLooper()).post { channel.invokeMethod("stop", null) }
  }

  override fun close() {
    stop()
  }
}
