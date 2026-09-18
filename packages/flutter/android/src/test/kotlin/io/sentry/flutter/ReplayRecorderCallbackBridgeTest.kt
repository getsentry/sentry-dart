package io.sentry.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

class ReplayRecorderCallbackBridgeTest {
  @Test
  fun `drops callbacks before attach and after detach`() {
    val bridge = ReplayRecorderCallbackBridge()
    val delegate = RecordingReplayCallbacks()

    bridge.replayStarted("before", false)
    bridge.attach(delegate)
    bridge.replayStarted("attached", false)
    bridge.detach()
    bridge.replayStarted("after", false)

    assertEquals(listOf("attached"), delegate.startedReplayIds)
  }

  @Test
  fun `replaces an attached delegate`() {
    val bridge = ReplayRecorderCallbackBridge()
    val first = RecordingReplayCallbacks()
    val second = RecordingReplayCallbacks()

    bridge.attach(first)
    bridge.attach(second)
    bridge.replayStarted("replay-id", false)

    assertEquals(emptyList<String>(), first.startedReplayIds)
    assertEquals(listOf("replay-id"), second.startedReplayIds)
  }
}

private class RecordingReplayCallbacks : ReplayRecorderCallbacks {
  val startedReplayIds = mutableListOf<String>()

  override fun replayStarted(
    replayId: String,
    replayIsBuffering: Boolean,
  ) {
    startedReplayIds.add(replayId)
  }

  override fun replayResumed() = Unit

  override fun replayStateChanged(
    replayId: String,
    replayIsBuffering: Boolean,
  ) = Unit

  override fun replayPaused() = Unit

  override fun replayStopped() = Unit

  override fun replayReset() = Unit

  override fun replayConfigChanged(
    width: Int,
    height: Int,
    frameRate: Int,
  ) = Unit
}
