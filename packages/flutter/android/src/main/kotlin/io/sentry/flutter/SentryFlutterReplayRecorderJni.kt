package io.sentry.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.sentry.Sentry
import io.sentry.protocol.SentryId
import io.sentry.android.replay.Recorder
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig

internal class SentryFlutterReplayRecorderJni(
  private val callbacks: ReplayRecorderCallbacks,
  private val integration: ReplayIntegration,
) : Recorder {
  private val main = Handler(Looper.getMainLooper())

  override fun start() {
    main.post {
      try {
        val replayId = integration.getReplayId().toString()
        var buffering = false
        Sentry.configureScope { scope ->
          buffering = scope.replayId == SentryId.EMPTY_ID
        }
        callbacks.replayStarted(replayId, buffering)
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to start replay recorder (JNI)", t)
      }
    }
  }

  override fun resume() {
    main.post {
      try {
        callbacks.replayResumed()
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to resume replay recorder (JNI)", t)
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
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to propagate configuration (JNI)", t)
      }
    }
  }

  override fun reset() {
    main.post {
      try {
        callbacks.replayReset()
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to reset replay recorder (JNI)", t)
      }
    }
  }

  override fun pause() {
    main.post {
      try {
        callbacks.replayPaused()
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to pause replay recorder (JNI)", t)
      }
    }
  }

  override fun stop() {
    main.post {
      try {
        callbacks.replayStopped()
      } catch (t: Throwable) {
        Log.w("Sentry", "Failed to stop replay recorder (JNI)", t)
      }
    }
  }

  override fun close() {
    stop()
  }
}


