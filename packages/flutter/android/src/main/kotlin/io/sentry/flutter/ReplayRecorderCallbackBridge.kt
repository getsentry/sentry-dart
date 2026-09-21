package io.sentry.flutter

/**
 * Keeps the native replay integration independent from the lifetime of a Dart
 * isolate. Calls are ignored until Flutter attaches a callback delegate.
 */
internal class ReplayRecorderCallbackBridge : ReplayRecorderCallbacks {
  @Volatile private var delegate: ReplayRecorderCallbacks? = null

  fun attach(callbacks: ReplayRecorderCallbacks) {
    delegate = callbacks
  }

  fun detach() {
    delegate = null
  }

  override fun replayStarted(
    replayId: String,
    replayIsBuffering: Boolean,
  ) {
    delegate?.replayStarted(replayId, replayIsBuffering)
  }

  override fun replayResumed() {
    delegate?.replayResumed()
  }

  override fun replayStateChanged(
    replayId: String,
    replayIsBuffering: Boolean,
  ) {
    delegate?.replayStateChanged(replayId, replayIsBuffering)
  }

  override fun replayPaused() {
    delegate?.replayPaused()
  }

  override fun replayStopped() {
    delegate?.replayStopped()
  }

  override fun replayReset() {
    delegate?.replayReset()
  }

  override fun replayConfigChanged(
    width: Int,
    height: Int,
    frameRate: Int,
  ) {
    delegate?.replayConfigChanged(width, height, frameRate)
  }
}
