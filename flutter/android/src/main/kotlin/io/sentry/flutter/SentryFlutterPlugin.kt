package io.sentry.flutter

import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.sentry.core.SentryOptions
import io.sentry.core.Sentry
import io.sentry.android.core.SentryAndroid
import android.content.Context
import java.nio.charset.Charset;
import java.io.File;
import java.util.UUID;

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var ctx: Context? = null
  private var cacheDir: String? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    ctx = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)
  }

  // Required by Flutter Android projects v1.12 and older
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "sentry_flutter")
      channel.setMethodCallHandler(SentryFlutterPlugin())
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${Build.VERSION.RELEASE}")
    } else if (call.method == "initNativeSdk") {
      val args = call.arguments() as Map<String, Any>

      SentryAndroid.init(ctx!!) { options ->
        options.dsn = args["dsn"] as String?
        options.isDebug = args["debug"] as Boolean
        options.environment = args["environment"] as String?
        options.release = args["release"] as String?
        options.dist = args["dist"] as String?
        options.setDebug(args["debug"] as Boolean)
        options.isEnableSessionTracking = args["autoSessionTracking"] as Boolean
        options.isAttachThreads = false

        val nativeCrashHandling = args["nativeCrashHandling"] as Boolean

        if (nativeCrashHandling) {
          // disable UncaughtExceptionHandlerIntegration, AnrIntegration, NdkIntegration
        }

        // missing maxBreadcrumbs, diagnosticLevel, inApps, dist
        // add flutter to sdk to packages + integrations, sessionTrackingIntervalMillis, attachStacktrace

        cacheDir = options.outboxPath
      }
      // RN uses beforeSend to do this things
      Sentry.configureScope { scope ->
        scope.setTag("web", (args["web"] as Boolean).toString())
        scope.setTag("platform", args["platform"] as String)
      }

      result.success("")
    } else if (call.method == "captureEnvelope") {

      val args = call.arguments() as Map<String, Any>
      val event = args["event"] as String
      println("$event event come")

      writeEnvelope(event)
    }
    // result.notImplemented()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  fun writeEnvelope(enveloe: String) {
    val file = File(cacheDir, UUID.randomUUID().toString())
    println(file)
    file.writeText(enveloe, Charsets.UTF_8)
  }
}
