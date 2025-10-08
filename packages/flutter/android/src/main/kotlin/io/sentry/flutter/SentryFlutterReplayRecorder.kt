package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorder(
  private val channel: MethodChannel,
  private val integration: ReplayIntegration,
) : Recorder {
  override fun start() {
    Handler(Looper.getMainLooper()).post {
      try {
        var scopeReplayId: String? = null
        Sentry.configureScope { scope ->
          scopeReplayId = scope.replayId?.toString()
        }
        channel.invokeMethod(
          "ReplayRecorder.start",
          mapOf(
            "scope.replayId" to scopeReplayId,
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

  override fun onConfigurationChanged(config: ScreenshotRecorderConfig) {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod(
          "ReplayRecorder.onConfigurationChanged",
          mapOf(
            "width" to config.recordingWidth,
            "height" to config.recordingHeight,
            "frameRate" to config.frameRate,
          ),
        )
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to propagate configuration change to Flutter", ignored)
      }
    }
  }

  override fun reset() {
    Handler(Looper.getMainLooper()).post {
      try {
        channel.invokeMethod("ReplayRecorder.reset", null)
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to reset replay recorder", ignored)
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
