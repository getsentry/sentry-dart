package io.sentry.flutter

interface ReplayRecorderCallbacks {
  fun replayStarted(
    replayId: String,
    replayIsBuffering: Boolean,
  )

  fun replayResumed()

  fun replayFlushed(requestId: Long)

  fun replayStateChanged(
    replayId: String,
    replayIsBuffering: Boolean,
  )

  fun replayPaused()

  fun replayStopped()

  fun replayReset()

  fun replayConfigChanged(
    width: Int,
    height: Int,
    frameRate: Int,
  )
}
