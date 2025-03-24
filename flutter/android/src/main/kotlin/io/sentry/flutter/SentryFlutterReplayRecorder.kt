package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorder(
  private val channel: MethodChannel,
  private val integration: ReplayIntegration,
) : Recorder {
  override fun start(recorderConfig: ScreenshotRecorderConfig) {
    // Ignore if this is the initial call before we actually got the configuration from Flutter.
    // We'll get another call here when the configuration is changed according to the widget size.
    if (recorderConfig.recordingHeight <= VIDEO_BLOCK_SIZE && recorderConfig.recordingWidth <= VIDEO_BLOCK_SIZE) {
      return
    }

    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod(
          "ReplayRecorder.start",
          mapOf(
            "width" to recorderConfig.recordingWidth,
            "height" to recorderConfig.recordingHeight,
            "frameRate" to recorderConfig.frameRate,
            "replayId" to integration.getReplayId().toString(),
          ),
        )
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to start replay recorder", ignored)
      }
    }
  }

  override fun resume() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.resume", null)
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to resume replay recorder", ignored)
      }
    }
  }

  override fun pause() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.pause", null)
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to pause replay recorder", ignored)
      }
    }
  }

  override fun stop() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.stop", null)
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to stop replay recorder", ignored)
      }
    }
  }

  override fun close() {
    stop()
  }
}
