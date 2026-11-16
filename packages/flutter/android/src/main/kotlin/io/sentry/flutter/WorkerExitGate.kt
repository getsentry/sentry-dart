package io.sentry.flutter

import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Holds engine teardown until the engine's Sentry worker isolates have asked to exit.
 *
 * Flutter releases its GPU objects in isolate-group finalizers, which run on whichever isolate
 * leaves the group last. If that is a worker isolate, they run on a Dart thread-pool thread
 * after the engine destroyed its Vulkan device and crash in the driver
 * (getsentry/sentry-dart#4092). The gate keeps the root isolate last.
 *
 * Protocol, once per engine detach, identified by a token that is unique in the process and
 * only ever sent over that engine's method channel:
 * 1. The root isolate calls [arm] once for every worker it tells to stop.
 * 2. The plugin calls [await] on the platform thread, which holds engine teardown.
 * 3. Each worker calls [requestExit] as its last step.
 *
 * Invariant: no worker is granted after [await] has returned for its token. [await] closes the
 * token, and a closed token stays closed for the life of the process, whatever [await] returned
 * and whether or not the worker was armed. A worker that asks for a closed token gets no
 * answer: its thread is parked, so its isolate group can neither shut down nor collect garbage
 * after the engine is gone.
 *
 * Before [await] closes the token, the order of [arm] and [requestExit] does not matter: a
 * worker that asks before it was armed is granted and counted.
 *
 * "Granted" is not "exited". The Dart VM gives no signal once an isolate has left its group, so
 * [await] holds teardown for [graceMillis] after the last grant to let the isolate finish.
 */
internal class WorkerExitGate(
  private val graceMillis: Long = DEFAULT_GRACE_MILLIS,
  private val sleep: (Long) -> Unit = { Thread.sleep(it) },
  private val log: (String) -> Unit = { Log.w("Sentry", it) },
  private val block: () -> Unit = ::parkForever,
) {
  private class Exit {
    var armed = 0
    var granted = 0
    var closed = false
  }

  private val lock = ReentrantLock()
  private val changed = lock.newCondition()

  // Entries are never removed: a forgotten token would be granted again, after its engine is
  // gone. Tokens are not reused and there is one per engine detach, so the map stays tiny.
  private val exits = HashMap<Long, Exit>()

  /** Announces one worker that will call [requestExit] with [token]. */
  fun arm(token: Long) {
    lock.withLock { exitFor(token).armed++ }
  }

  /**
   * Blocks until every worker armed for [token] was granted or [timeoutMillis] passed, then
   * closes the token for good. Returns false if workers were still outstanding when it closed.
   */
  fun await(
    token: Long,
    timeoutMillis: Long,
  ): Boolean {
    var allGranted = false
    var anyGranted = false
    lock.withLock {
      val exit = exitFor(token)
      var remainingNanos = TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
      try {
        while (exit.granted < exit.armed && remainingNanos > 0) {
          remainingNanos = changed.awaitNanos(remainingNanos)
        }
      } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
      }
      exit.closed = true
      allGranted = exit.granted >= exit.armed
      anyGranted = exit.granted > 0
    }
    // The grace period is for granted isolates to finish. Without a grant nothing is exiting.
    if (allGranted && anyGranted) {
      try {
        sleep(graceMillis)
      } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
      }
    }
    return allGranted
  }

  /**
   * Called by a worker isolate as its last step. Returns true if it may exit. If [await] has
   * already closed [token], it neither returns nor throws: the calling thread is parked for the
   * life of the process.
   */
  fun requestExit(token: Long): Boolean {
    val granted =
      lock.withLock {
        val exit = exitFor(token)
        if (!exit.closed) {
          exit.granted++
          changed.signalAll()
        }
        !exit.closed
      }
    if (!granted) {
      park(token)
    }
    return granted
  }

  private fun exitFor(token: Long) = exits.getOrPut(token) { Exit() }

  private fun park(token: Long) {
    try {
      Thread.currentThread().name = PARKED_THREAD_NAME
      log(
        "A Sentry worker isolate did not exit before its engine was destroyed (token $token). " +
          "Parking its thread: exiting now would release GPU resources after the engine is gone.",
      )
    } finally {
      // The name and the log line are diagnostics. The park is what prevents the crash, so it
      // must happen even if they throw.
      block()
    }
  }

  companion object {
    const val DEFAULT_GRACE_MILLIS = 5L
    const val PARKED_THREAD_NAME = "SentryParkedWorkerIsolate"
  }
}

/**
 * Never returns. An interrupt must not end the park, since returning lets the isolate exit
 * after its engine is gone.
 */
private fun parkForever() {
  val never = CountDownLatch(1)
  while (true) {
    try {
      never.await()
    } catch (e: InterruptedException) {
      // Stay parked. The interrupt flag is left cleared, or the next await would throw again.
    }
  }
}
