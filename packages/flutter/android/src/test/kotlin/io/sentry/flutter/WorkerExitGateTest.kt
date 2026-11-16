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
  fun `requestExit grants a token that was never armed`() {
    val sut = getSut()

    assertTrue(sut.requestExit(1))
    assertEquals(0, blocked.get())
  }

  @Test
  fun `await returns true once every armed worker was granted`() {
    val sut = getSut()
    sut.arm(1)
    sut.arm(1)

    assertTrue(sut.requestExit(1))
    assertTrue(sut.requestExit(1))
    assertTrue(sut.await(1, 1000))
  }

  @Test
  fun `await holds the grace period after the last grant`() {
    val sut = getSut()
    sut.arm(1)
    sut.requestExit(1)

    sut.await(1, 1000)

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
  fun `await returns false without a grace period when a worker did not ask in time`() {
    val sut = getSut()
    sut.arm(1)

    assertFalse(sut.await(1, 0))
    assertEquals(emptyList<Long>(), slept)
  }

  @Test
  fun `requestExit parks a worker that asks after await gave up`() {
    val sut = getSut()
    sut.arm(1)
    sut.await(1, 0)

    assertFalse(sut.requestExit(1))
    assertEquals(1, blocked.get())
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
  fun `requestExit parks a second request after await returned true`() {
    val sut = getSut()
    sut.arm(1)
    sut.requestExit(1)
    assertTrue(sut.await(1, 1000))

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
    sut.requestExit(1)

    assertTrue(sut.await(1, 0))
    assertEquals(listOf(5L), slept)
  }

  @Test(timeout = 10_000)
  fun `await gives up after its timeout when a worker never asks`() {
    val sut = getSut()
    sut.arm(1)

    assertFalse(sut.await(1, 50))
  }

  @Test(timeout = 10_000)
  fun `requestExit stays parked when its thread is interrupted`() {
    val sut = WorkerExitGate(log = { logged.add(it) })
    sut.arm(1)
    sut.await(1, 0)
    val worker = thread(isDaemon = true) { sut.requestExit(1) }
    while (worker.state != Thread.State.WAITING) Thread.yield()

    worker.interrupt()
    worker.join(200)

    assertTrue(worker.isAlive)
  }

  @Test
  fun `requestExit stays parked when its thread was interrupted before it asked`() {
    val sut = WorkerExitGate(log = { logged.add(it) })
    sut.arm(1)
    sut.await(1, 0)

    val worker =
      thread(isDaemon = true) {
        Thread.currentThread().interrupt()
        sut.requestExit(1)
      }
    worker.join(200)

    assertTrue(worker.isAlive)
  }

  @Test
  fun `requestExit parks even when logging throws`() {
    val sut =
      WorkerExitGate(
        log = { throw IllegalStateException("log failed") },
        block = { blocked.incrementAndGet() },
      )
    sut.arm(1)
    sut.await(1, 0)

    runCatching { sut.requestExit(1) }

    assertEquals(1, blocked.get())
  }
}
