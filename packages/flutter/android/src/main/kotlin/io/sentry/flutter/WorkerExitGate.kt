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
 * Invariant: no armed worker is granted after [await] has returned. A worker that asks too late
 * gets no answer: its thread is parked, so its isolate group can neither shut down nor collect
 * garbage after the engine is gone.
 *
 * "Granted" is not "exited". The Dart VM gives no signal once an isolate has left its group, so
 * [await] holds teardown for [graceMillis] after the last grant to let the isolate finish.
 */
internal class WorkerExitGate(
  private val graceMillis: Long = DEFAULT_GRACE_MILLIS,
  private val sleep: (Long) -> Unit = { Thread.sleep(it) },
  private val log: (String) -> Unit = { Log.w("Sentry", it) },
  private val block: () -> Unit = { CountDownLatch(1).await() },
) {
  private class Exit {
    var armed = 0
    var granted = 0
    var closed = false
  }

  private val lock = ReentrantLock()
  private val changed = lock.newCondition()
  private val exits = HashMap<Long, Exit>()

  /** Announces one worker that will call [requestExit] with [token]. */
  fun arm(token: Long) {
    lock.withLock { exits.getOrPut(token) { Exit() }.armed++ }
  }

  /**
   * Blocks until every worker armed for [token] was granted or [timeoutMillis] passed, then
   * closes the token. Returns false if workers were still outstanding when it closed.
   */
  fun await(
    token: Long,
    timeoutMillis: Long,
  ): Boolean {
    val allGranted =
      lock.withLock {
        val exit = exits[token] ?: return true
        var remainingNanos = TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
        try {
          while (exit.granted < exit.armed && remainingNanos > 0) {
            remainingNanos = changed.awaitNanos(remainingNanos)
          }
        } catch (e: InterruptedException) {
          Thread.currentThread().interrupt()
        }
        exit.closed = true
        val allGranted = exit.granted == exit.armed
        if (allGranted) exits.remove(token)
        allGranted
      }
    if (allGranted) {
      try {
        sleep(graceMillis)
      } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
      }
    }
    return allGranted
  }

  /**
   * Called by a worker isolate as its last step. Returns true if it may exit. Does not return
   * if the worker was armed and [await] has already given up on it.
   */
  fun requestExit(token: Long): Boolean {
    val granted =
      lock.withLock {
        val exit = exits[token] ?: return true
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

  private fun park(token: Long) {
    Thread.currentThread().name = PARKED_THREAD_NAME
    log(
      "A Sentry worker isolate did not exit before its engine was destroyed (token $token). " +
        "Parking its thread: exiting now would release GPU resources after the engine is gone.",
    )
    block()
  }

  companion object {
    const val DEFAULT_GRACE_MILLIS = 5L
    const val PARKED_THREAD_NAME = "SentryParkedWorkerIsolate"
  }
}
