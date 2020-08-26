package io.sentry.flutter.example

import android.content.Context
import androidx.annotation.NonNull
import androidx.work.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.core.Sentry

class MainActivity: FlutterActivity() {
  private val _channel = "example.flutter.sentry.io"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, _channel).setMethodCallHandler {
      call, result ->
      // Note: this method is invoked on the main thread.
      when (call.method) {
          "throw" -> {
            throw Exception("Thrown from Kotlin!")
          }
          "background" -> {
            WorkManager.getInstance(this)
                    .enqueue(OneTimeWorkRequestBuilder<BrokenWorker>()
                            .build())
          }
          "anr" -> {
            Thread.sleep(6_000)
          }
          "capture" -> {
            try {
              throw RuntimeException("Catch this exception!")
            } catch (e: Exception) {
              Sentry.captureException(e);
            }
          }
              "crash" -> {
              crash();
          }
          "native_capture_message" -> {
              message();
          }
          else -> {
            result.notImplemented()
          }
      }
    }
  }

  external fun crash(): Unit?
  external fun message(): Unit?

  companion object {
    init {
      System.loadLibrary("native-sample")
    }
  }

  class BrokenWorker(appContext: Context, workerParams: WorkerParameters): Worker(appContext, workerParams)
  {
    override fun doWork(): Result
    {
      throw RuntimeException("Kotlin background task")
      return Result.success()
    }
  }
}
