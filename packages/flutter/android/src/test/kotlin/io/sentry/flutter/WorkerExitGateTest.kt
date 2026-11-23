package io.sentry.flutter

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

class WorkerExitGateTest {
  private val slept = CopyOnWriteArrayList<Long>()
  private val logged = CopyOnWriteArrayList<String>()
  private val blocked = AtomicInteger()
  private val testThreadName = Thread.currentThread().name

  private fun getSut() =
    WorkerExitGate(
      graceMillis = 5,
      sleep = { slept.add(it) },
      log = { logged.add(it) },
      block = { blocked.incrementAndGet() },
    )

  // Returns the state of [thread] once it is parked or has ended. Nothing else on the way to the
  // park makes it wait. Polls, so callers need a JUnit timeout.
  private fun awaitParkedOrEnded(thread: Thread): Thread.State {
    while (true) {
      val state = thread.state
      if (state == Thread.State.WAITING || state == Thread.State.TERMINATED) return state
      Thread.yield()
    }
  }

  // A denied requestExit renames the thread it parks. With the fake block that is the JUnit
  // thread, which would carry the name into the tests that run after.
  @After
  fun restoreTestThreadName() {
    Thread.currentThread().name = testThreadName
  }

  @Test
  fun `await returns true without a grace period when nothing was armed`() {
    val sut = getSut()

    assertTrue(sut.await(1, 1000))
    assertEquals(emptyList<Long>(), slept)
  }

  @Test
  fun `await returns true after the grace period once every armed worker was granted`() {
    val sut = getSut()
    sut.arm(1)
    sut.arm(1)

    assertTrue(sut.requestExit(1))
    assertTrue(sut.requestExit(1))
    assertTrue(sut.await(1, 1000))
    assertEquals(listOf(5L), slept)
  }

  @Test(timeout = 10_000)
  fun `await returns as soon as a worker on another thread is granted`() {
    val sut = getSut()
    sut.arm(1)
    val waiter = Thread.currentThread()
    val worker =
      Thread {
        while (waiter.state != Thread.State.TIMED_WAITING) Thread.yield()
        sut.requestExit(1)
      }
    worker.start()

    assertTrue(sut.await(1, TimeUnit.MINUTES.toMillis(1)))
    worker.join()
  }

  @Test
  fun `requestExit parks only the late worker of two`() {
    val sut = getSut()
    sut.arm(1)
    sut.arm(1)

    assertTrue(sut.requestExit(1))
    assertFalse(sut.await(1, 0))
    assertFalse(sut.requestExit(1))
    assertEquals(1, blocked.get())
  }

  @Test
  fun `requestExit names the parked thread and logs the token`() {
    val sut = getSut()
    sut.arm(1)
    sut.await(1, 0)
    var name = ""
    val worker =
      Thread {
        sut.requestExit(1)
        name = Thread.currentThread().name
      }

    worker.start()
    worker.join()

    assertEquals("SentryParkedWorkerIsolate", name)
    assertTrue(logged.single().contains("token 1"))
  }

  @Test
  fun `await giving up on one token does not affect another`() {
    val sut = getSut()
    sut.arm(1)
    sut.arm(2)
    sut.await(1, 0)

    assertTrue(sut.requestExit(2))
    assertTrue(sut.await(2, 1000))
    assertEquals(0, blocked.get())
  }

  @Test
  fun `requestExit parks a worker armed after await returned true`() {
    val sut = getSut()
    sut.arm(1)
    sut.requestExit(1)
    assertTrue(sut.await(1, 1000))
    sut.arm(1)

    assertFalse(sut.requestExit(1))
    assertEquals(1, blocked.get())
  }

  @Test
  fun `requestExit parks a worker armed after await returned for a token nobody had armed`() {
    val sut = getSut()
    assertTrue(sut.await(1, 1000))
    sut.arm(1)

    assertFalse(sut.requestExit(1))
    assertEquals(1, blocked.get())
  }

  @Test
  fun `await returns true with the grace period when a worker asked before it was armed`() {
    val sut = getSut()
    sut.requestExit(1)
    sut.arm(1)

    assertTrue(sut.await(1, 0))
    assertEquals(listOf(5L), slept)
  }

  @Test
  fun `await returns true with the grace period when a worker asked without being armed`() {
    val sut = getSut()

    assertTrue(sut.requestExit(1))
    assertTrue(sut.await(1, 0))
    assertEquals(listOf(5L), slept)
    assertEquals(0, blocked.get())
  }

  @Test(timeout = 10_000)
  fun `await gives up after its timeout without a grace period when a worker never asks`() {
    val sut = getSut()
    sut.arm(1)

    assertFalse(sut.await(1, 50))
    assertEquals(emptyList<Long>(), slept)
  }

  @Test(timeout = 10_000)
  fun `await gives up after its timeout with the grace period when one of two workers asked`() {
    val sut = getSut()
    sut.arm(1)
    sut.arm(1)

    assertTrue(sut.requestExit(1))
    assertFalse(sut.await(1, 50))
    assertEquals(listOf(5L), slept)
  }

  @Test(timeout = 10_000)
  fun `requestExit stays parked when its thread is interrupted`() {
    val sut = WorkerExitGate(log = { logged.add(it) })
    sut.arm(1)
    sut.await(1, 0)
    val worker = thread(isDaemon = true) { sut.requestExit(1) }
    assertEquals(Thread.State.WAITING, awaitParkedOrEnded(worker))

    worker.interrupt()
    // The park clears the interrupt flag when it handles the interrupt. Until then the thread
    // still shows the waiting state from before the interrupt.
    while (worker.isInterrupted && worker.isAlive) Thread.yield()

    assertEquals(Thread.State.WAITING, awaitParkedOrEnded(worker))
  }
}
