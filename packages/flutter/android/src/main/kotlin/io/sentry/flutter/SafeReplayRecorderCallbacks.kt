package io.sentry.flutter

import android.util.Log
import java.util.concurrent.atomic.AtomicInteger

/**
 * Wraps [ReplayRecorderCallbacks] and guards all callbacks behind a generation check (to ignore stale callbacks from previous isolates).
 * Without this check the app would crash after a hot-restart in debug mode.
 */
internal class SafeReplayRecorderCallbacks(
  private val delegate: ReplayRecorderCallbacks,
) : ReplayRecorderCallbacks {
  companion object {
    private val generationCounter = AtomicInteger(0)

    fun bumpGeneration() {
      generationCounter.incrementAndGet()
    }

    fun currentGeneration(): Int = generationCounter.get()
  }

  private val generationSnapshot: Int = currentGeneration()

  private inline fun guard(block: () -> Unit) {
    if (generationSnapshot != currentGeneration()) return
    try {
      block()
    } catch (t: Throwable) {
      Log.w("Sentry", "Replay recorder callback failed", t)
    }
  }

  override fun replayStarted(
    replayId: String,
    replayIsBuffering: Boolean,
  ) = guard {
    delegate.replayStarted(replayId, replayIsBuffering)
  }

  override fun replayResumed() =
    guard {
      delegate.replayResumed()
    }

  override fun replayPaused() =
    guard {
      delegate.replayPaused()
    }

  override fun replayStopped() =
    guard {
      delegate.replayStopped()
    }

  override fun replayReset() =
    guard {
      delegate.replayReset()
    }

  override fun replayConfigChanged(
    width: Int,
    height: Int,
    frameRate: Int,
  ) = guard {
    delegate.replayConfigChanged(width, height, frameRate)
  }
}
