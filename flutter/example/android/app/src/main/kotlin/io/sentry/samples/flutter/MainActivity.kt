package io.sentry.samples.flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
  private val _channel = "example.flutter.sentry.io"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, _channel).setMethodCallHandler {
      call, result ->
      // Note: this method is invoked on the main thread.
      when (call.method) {
        "throw" -> {
          thread(isDaemon = true) {
            throw Exception("Thrown from Kotlin!")
          }
        }
        "anr" -> {
          Thread.sleep(6_000)
        }
        "capture" -> {
          try {
            throw RuntimeException("Catch this exception!")
          } catch (e: Exception) {
            Sentry.captureException(e)
          }
        }
        "crash" -> {
          crash()
        }
        "cpp_capture_message" -> {
          message()
        }
        "platform_exception" -> {
          result.success(Thread.currentThread().getStackTrace())
        }
        else -> {
          result.notImplemented()
        }
      }
      result.success("")
    }
  }

  private external fun crash()
  private external fun message()

  companion object {
    init {
      System.loadLibrary("native-sample")
    }
  }
}
