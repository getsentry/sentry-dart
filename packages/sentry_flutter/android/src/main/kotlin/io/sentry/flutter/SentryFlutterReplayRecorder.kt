package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.sentry.Sentry
import io.sentry.protocol.SentryId
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorder(
  private val callbacks: ReplayRecorderCallbacks,
  private val integration: ReplayIntegration,
) : Recorder {
  override fun start() {
    Handler(Looper.getMainLooper()).post {
      try {
        val replayId = integration.getReplayId().toString()
        var replayIsBuffering = false
        Sentry.configureScope { scope ->
          // Buffering mode: we have a replay ID but it's not set on scope yet
          replayIsBuffering = scope.replayId == SentryId.EMPTY_ID
        }
        callbacks.replayStarted(replayId, replayIsBuffering)
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to start replay recorder", ignored)
      }
    }
  }

  override fun resume() {
    Handler(Looper.getMainLooper()).post {
      try {
        callbacks.replayResumed()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to resume replay recorder", ignored)
      }
    }
  }

  override fun onConfigurationChanged(config: ScreenshotRecorderConfig) {
    Handler(Looper.getMainLooper()).post {
      try {
        callbacks.replayConfigChanged(
          config.recordingWidth,
          config.recordingHeight,
          config.frameRate,
        )
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to propagate configuration change to Flutter", ignored)
      }
    }
  }

  override fun reset() {
    Handler(Looper.getMainLooper()).post {
      try {
        callbacks.replayReset()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to reset replay recorder", ignored)
      }
    }
  }

  override fun pause() {
    Handler(Looper.getMainLooper()).post {
      try {
        callbacks.replayPaused()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to pause replay recorder", ignored)
      }
    }
  }

  override fun stop() {
    Handler(Looper.getMainLooper()).post {
      try {
        callbacks.replayStopped()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to stop replay recorder", ignored)
      }
    }
  }

  override fun close() {
    stop()
  }
}
