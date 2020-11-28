package io.sentry.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.SentryOptions
import io.sentry.android.core.SentryAndroid
import io.sentry.protocol.SdkVersion
import java.io.File
import java.util.Locale
import java.util.UUID

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var options: SentryOptions

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initNativeSdk" -> initNativeSdk(call, result)
      "captureEnvelope" -> captureEnvelope(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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
    if (args.isEmpty()) {
      result.error("4", "Arguments is null or empty", null)
      return
    }

    SentryAndroid.init(context) { options ->
      (args["dsn"] as? String)?.let {
        options.dsn = it
      }
      (args["debug"] as? Boolean)?.let {
        options.isDebug = it
      }
      (args["environment"] as? String)?.let {
        options.environment = it
      }
      (args["release"] as? String)?.let {
        options.release = it
      }
      (args["dist"] as? String)?.let {
        options.dist = it
      }
      (args["enableAutoSessionTracking"] as? Boolean)?.let {
        options.isEnableSessionTracking = it
      }
      (args["autoSessionTrackingIntervalMillis"] as? Long)?.let {
        options.sessionTrackingIntervalMillis = it
      }
      (args["anrTimeoutIntervalMillis"] as? Long)?.let {
        options.anrTimeoutIntervalMillis = it
      }
      // expose options for isAttachThreads?
      (args["attachStacktrace"] as? Boolean)?.let {
        options.isAttachStacktrace = it
      }
      (args["enableAutoNativeBreadcrumbs"] as? Boolean)?.let {
        options.isEnableActivityLifecycleBreadcrumbs = it
        options.isEnableAppLifecycleBreadcrumbs = it
        options.isEnableSystemEventBreadcrumbs = it
        options.isEnableAppComponentBreadcrumbs = it
      }
      (args["maxBreadcrumbs"] as? Int)?.let {
        options.maxBreadcrumbs = it
      }
      (args["cacheDirSize"] as? Int)?.let {
        options.cacheDirSize = it
      }
      (args["diagnosticLevel"] as? String)?.let {
        val sentryLevel = SentryLevel.valueOf(it.toUpperCase(Locale.ROOT))
        options.setDiagnosticLevel(sentryLevel)
      }

      val anrEnabled = (args["anrEnabled"] as? Boolean) ?: options.isAnrEnabled
      options.isAnrEnabled = anrEnabled

      val nativeCrashHandling = (args["enableNativeCrashHandling"] as? Boolean) ?: false

      // nativeCrashHandling has priority over anrEnabled
      if (!nativeCrashHandling) {
        options.isEnableUncaughtExceptionHandler = false
        options.isAnrEnabled = false

        // if split symbols are enabled, we need Ndk integration so we can't really offer the option
        // to turn it off
        // options.isEnableNdk = false
      }

      options.setBeforeSend { event, _ ->
        setEventOriginTag(event)
        addPackages(event, options.sdkVersion)
        removeThreadsIfNotAndroid(event)

        // TODO: merge debug images from Native

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

  private val flutterSdk = "sentry.dart.flutter"
  private val androidSdk = "sentry.java.android"
  private val nativeSdk = "sentry.native"

  private fun setEventOriginTag(event: SentryEvent) {
    val sdk = event.sdk
    if (isValidSdk(sdk)) {
      when (sdk.name) {
        flutterSdk -> setEventEnvironmentTag(event, "flutter", "dart")
        androidSdk -> setEventEnvironmentTag(event, environment = "java")
        nativeSdk -> setEventEnvironmentTag(event, environment = "native")
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
        flutterSdk -> {
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

  private fun removeThreadsIfNotAndroid(event: SentryEvent) {
    if (isValidSdk(event.sdk)) {
      // we do not want the thread list if not an android event, the thread info is mostly about
      // the file observer anyway
      if (event.sdk.name != androidSdk && event.threads != null) {
        event.threads.clear()
      }
    }
  }
}
