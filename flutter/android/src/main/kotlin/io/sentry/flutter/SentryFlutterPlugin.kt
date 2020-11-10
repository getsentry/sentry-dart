package io.sentry.flutter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.sentry.android.core.SentryAndroid
import android.content.Context
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.SentryOptions
import io.sentry.protocol.SdkVersion
import java.io.File
import java.util.*

// TODO: maybe this should be done in Java, to avoid stdlib
// libflutter.so is already 11mb each archie

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var options: SentryOptions

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)
  }
  // TODO: should we remove this if we do minSDK flutter >= that?
  // Required by Flutter Android projects v1.12 and older
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "sentry_flutter")
      channel.setMethodCallHandler(SentryFlutterPlugin())
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when(call.method) {
      "initNativeSdk" -> initNativeSdk(call, result)
      "captureEnvelope" -> captureEnvelope(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    if (!this::channel.isInitialized) {
      return
    }

    channel.setMethodCallHandler(null)
  }

  private fun writeEnvelope(envelope: String): Boolean {
    if (!this::options.isInitialized || options.outboxPath.isNullOrEmpty()) {
      return false
    }

    val file = File(options.outboxPath, UUID.randomUUID().toString())
    file.writeText(envelope, Charsets.UTF_8)

    return true
  }

  private fun initNativeSdk(call: MethodCall, result: Result) {
    if (!this::context.isInitialized) {
      result.error("1", "Context is null", null)
      return
    }

    val args = call.arguments() as Map<String, Any>

    SentryAndroid.init(context) { options ->
      options.dsn = args["dsn"] as String?
      options.isDebug = args["debug"] as Boolean
      options.environment = args["environment"] as String?
      options.release = args["release"] as String?
      options.dist = args["dist"] as String?
      options.isDebug = args["debug"] as Boolean
      options.isEnableSessionTracking = args["enableAutoSessionTracking"] as Boolean
      options.sessionTrackingIntervalMillis = (args["autoSessionTrackingIntervalMillis"] as Int).toLong()
      options.anrTimeoutIntervalMillis = (args["anrTimeoutIntervalMillis"] as Int).toLong()
      options.isAttachThreads = false
      options.isAttachStacktrace = args["attachStacktrace"] as Boolean

      val enableAutoNativeBreadcrumbs = args["enableAutoNativeBreadcrumbs"] as Boolean
      options.isEnableActivityLifecycleBreadcrumbs = enableAutoNativeBreadcrumbs
      options.isEnableAppLifecycleBreadcrumbs = enableAutoNativeBreadcrumbs
      options.isEnableSystemEventBreadcrumbs = enableAutoNativeBreadcrumbs
      options.isEnableAppComponentBreadcrumbs = enableAutoNativeBreadcrumbs

      options.maxBreadcrumbs = args["maxBreadcrumbs"] as Int
      options.cacheDirSize = args["cacheDirSize"] as Int

      val level = args["diagnosticLevel"] as String
      val sentryLevel = SentryLevel.valueOf(level.toUpperCase(Locale.ROOT))
      options.setDiagnosticLevel(sentryLevel)

      val nativeCrashHandling = args["enableNativeCrashHandling"] as Boolean

      if (!nativeCrashHandling) {
        options.isEnableUncaughtExceptionHandler = false
        options.isAnrEnabled = false
        options.isEnableNdk = false
      }

      options.setBeforeSend { event, _ ->
        setEventOriginTag(event)
        addPackages(event, options.sdkVersion)
        removeThreadsIfNotNative(event)

        event
      }

      // missing proxy, sendDefaultPii, enableScopeSync

      this.options = options
    }

    result.success("")
  }

  private fun captureEnvelope(call: MethodCall, result: Result) {
    val args = call.arguments() as List<Any>
    if (args.isNotEmpty()) {
      val event = args.first() as String?

      if (!event.isNullOrEmpty()) {
        if (!writeEnvelope(event)) {
          result.error("3", "SentryOptions or outboxPath are null or empty", null)
        }
        result.success("")
        return
      }
    }

    result.error("2", "Envelope is null or empty", null)
  }

  private fun setEventOriginTag(event: SentryEvent) {
    val sdk = event.sdk
    if (isValidSdk(sdk)) {
      when (sdk.name) {
        "sentry.dart.flutter" -> setEventEnvironmentTag(event, "flutter", "dart")
        "sentry.java.android" -> setEventEnvironmentTag(event, environment = "java")
        "sentry.native" -> setEventEnvironmentTag(event, environment = "native")
      }
    }
  }

  private fun setEventEnvironmentTag(event: SentryEvent, origin: String = "android", environment: String) {
    event.setTag("event.origin", origin)
    event.setTag("event.environment", environment)
  }

  private fun isValidSdk(sdk: SdkVersion?): Boolean {
    return (sdk != null && !sdk.name.isNullOrEmpty())
  }

  private fun addPackages(event: SentryEvent, sdk: SdkVersion?) {
    if (isValidSdk(event.sdk)) {
      when (event.sdk.name) {
        "sentry.dart.flutter" -> {
          sdk?.packages?.forEach { sentryPackage ->
            event.sdk.addPackage(sentryPackage.name, sentryPackage.version)
          }
          sdk?.integrations?.forEach { integration ->
            event.sdk.addIntegration(integration)
          }
        }
      }
    }
  }

  private fun removeThreadsIfNotNative(event: SentryEvent) {
    if (isValidSdk(event.sdk)) {
      // we do not want the thread list if not an android event, the thread info is mostly about
      // the file observer anyway
      if (event.sdk.name != "sentry.java.android" && event.threads != null) {
        event.threads.clear()
      }
    }
  }
}
