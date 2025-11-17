package io.sentry.flutter

interface ReplayRecorderCallbacks {
  fun replayStarted(
    replayId: String,
    replayIsBuffering: Boolean,
  )

  fun replayResumed()

  fun replayPaused()

  fun replayStopped()

  fun replayReset()

  fun replayConfigChanged(
    width: Int,
    height: Int,
    frameRate: Int,
  )
}
