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
  override fun start(config: ScreenshotRecorderConfig) {
    val cacheDirPath = integration.replayCacheDir?.absolutePath
    if (cacheDirPath == null) {
      Log.w("Sentry", "Replay cache directory is null, can't start replay recorder.")
      return
    }
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod(
            "ReplayRecorder.start",
            mapOf(
                "directory" to cacheDirPath,
                "width" to config.recordingWidth,
                "height" to config.recordingHeight,
                "frameRate" to config.frameRate,
            ),
        )
      } catch (e: Exception) {
        Log.w("Sentry", "Failed to start replay recorder", e)
      }
    }
  }

  override fun resume() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.resume", null)
      } catch (e: Exception) {
        Log.w("Sentry", "Failed to resume replay recorder", e)
      }
    }
  }

  override fun pause() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.pause", null)
      } catch (e: Exception) {
        Log.w("Sentry", "Failed to pause replay recorder", e)
      }
    }
  }

  override fun stop() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.stop", null)
      } catch (e: Exception) {
        Log.w("Sentry", "Failed to stop replay recorder", e)
      }
    }
  }

  override fun close() {
    stop()
  }
}
