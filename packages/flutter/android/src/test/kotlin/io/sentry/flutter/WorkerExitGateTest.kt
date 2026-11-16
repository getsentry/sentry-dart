package io.sentry.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class WorkerExitGateTest {
  private val slept = CopyOnWriteArrayList<Long>()
  private val logged = CopyOnWriteArrayList<String>()
  private val blocked = AtomicInteger()

  private fun getSut() =
    WorkerExitGate(
      graceMillis = 5,
      sleep = { slept.add(it) },
      log = { logged.add(it) },
      block = { blocked.incrementAndGet() },
    )

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
}
