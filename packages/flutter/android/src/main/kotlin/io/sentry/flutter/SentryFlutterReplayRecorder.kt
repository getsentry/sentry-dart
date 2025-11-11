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
  private val main = Handler(Looper.getMainLooper())

  override fun start() {
    main.post {
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
    main.post {
      try {
        callbacks.replayResumed()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to resume replay recorder", ignored)
      }
    }
  }

  override fun onConfigurationChanged(config: ScreenshotRecorderConfig) {
    main.post {
      try {
        callbacks.replayConfigChanged(
          config.recordingWidth,
          config.recordingHeight,
          config.frameRate,
        )
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to propagate configuration", ignored)
      }
    }
  }

  override fun reset() {
    main.post {
      try {
        callbacks.replayReset()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to reset replay recorder", ignored)
      }
    }
  }

  override fun pause() {
    main.post {
      try {
        callbacks.replayPaused()
      } catch (ignored: Exception) {
        Log.w("Sentry", "Failed to pause replay recorder", ignored)
      }
    }
  }

  override fun stop() {
    main.post {
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


