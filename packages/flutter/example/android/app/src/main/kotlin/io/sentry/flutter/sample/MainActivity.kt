package io.sentry.flutter.sample

import android.os.Handler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
  private val _channel = "example.flutter.sentry.io"
  private val mutex = Object()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      _channel,
    ).setMethodCallHandler { call, result ->
      // Note: this method is invoked on the main thread.
      when (call.method) {
        "throw" ->
          thread(isDaemon = true) {
            throw Exception("Catch this java exception thrown from Kotlin thread!")
          }

        "anr" -> anr()

        "capture" ->
          try {
            throw RuntimeException("Catch this java exception!")
          } catch (e: Exception) {
            Sentry.captureException(e)
          }

        "crash" -> crash()

        "cpp_capture_message" -> message()

        "platform_exception" -> throw RuntimeException("Catch this platform exception!")

        else -> result.notImplemented()
      }
      result.success("")
    }
  }

  @Suppress("MagicNumber")
  private fun anr() {
    // Try cause ANR by blocking for 10 seconds.
    // By default the SDK sends an event if blocked by at least 5 seconds.
    // Keep clicking on the ANR button till you've gotten the "App. isn''t responding" dialog,
    // then either click on Wait or Close, at this point you should have seen an event on
    // Sentry.
    // NOTE: By default it doesn't raise if the debugger is attached. That can also be
    // configured.

    val sleepDurationInMillis = 10000L

    Thread {
      synchronized(mutex) {
        while (true) {
          try {
            Thread.sleep(sleepDurationInMillis)
          } catch (e: InterruptedException) {
            e.printStackTrace()
          }
        }
      }
    }.start()

    Handler()
      .postDelayed(
        {
          synchronized(mutex) {
            // Shouldn't happen
            throw IllegalStateException("This should not happen.")
          }
        },
        sleepDurationInMillis,
      )
  }

  private external fun crash()

  private external fun message()

  companion object {
    init {
      System.loadLibrary("native-sample")
    }
  }
}
