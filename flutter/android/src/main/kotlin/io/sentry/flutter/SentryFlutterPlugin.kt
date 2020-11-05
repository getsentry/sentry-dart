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

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var ctx: Context? = null

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
        options.dsn = args["dsn"] as String
        options.setDebug(args["debug"] as Boolean)
        options.environment = args["environment"] as String
        options.release = args["release"] as String

        // missing maxBreadcrumbs, diagnosticLevel, inApps, dist
        // add flutter to sdk to packages + integrations
      }
      Sentry.configureScope { scope ->
        scope.setTag("web", (args["web"] as Boolean).toString())
        scope.setTag("platform", args["platform"] as String)
      }

      result.success("")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
