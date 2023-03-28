package io.sentry.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.sentry.HubAdapter
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SdkVersion
import java.io.File
import java.util.Locale
import java.util.UUID

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initNativeSdk" -> initNativeSdk(call, result)
      "captureEnvelope" -> captureEnvelope(call, result)
      "loadImageList" -> loadImageList(call, result)
      "closeNativeSdk" -> closeNativeSdk(result)
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
    val options = HubAdapter.getInstance().options
    if (options.outboxPath.isNullOrEmpty()) {
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

    val args = call.arguments() as Map<String, Any>? ?: mapOf<String, Any>()
    if (args.isEmpty()) {
      result.error("4", "Arguments is null or empty", null)
      return
    }

    SentryAndroid.init(context) { options ->
      args.getIfNotNull<String>("dsn") { options.dsn = it }
      args.getIfNotNull<Boolean>("debug") { options.setDebug(it) }
      args.getIfNotNull<String>("environment") { options.environment = it }
      args.getIfNotNull<String>("release") { options.release = it }
      args.getIfNotNull<String>("dist") { options.dist = it }
      args.getIfNotNull<Boolean>("enableAutoSessionTracking") { options.isEnableAutoSessionTracking = it }
      args.getIfNotNull<Long>("autoSessionTrackingIntervalMillis") { options.sessionTrackingIntervalMillis = it }
      args.getIfNotNull<Long>("anrTimeoutIntervalMillis") { options.anrTimeoutIntervalMillis = it }
      args.getIfNotNull<Boolean>("attachThreads") { options.isAttachThreads = it }
      args.getIfNotNull<Boolean>("attachStacktrace") { options.isAttachStacktrace = it }
      args.getIfNotNull<Boolean>("enableAutoNativeBreadcrumbs") {
        options.isEnableActivityLifecycleBreadcrumbs = it
        options.isEnableAppLifecycleBreadcrumbs = it
        options.isEnableSystemEventBreadcrumbs = it
        options.isEnableAppComponentBreadcrumbs = it
      }
      args.getIfNotNull<Int>("maxBreadcrumbs") { options.maxBreadcrumbs = it }
      args.getIfNotNull<Int>("cacheDirSize") { options.maxCacheItems = it }
      args.getIfNotNull<String>("diagnosticLevel") {
        if (options.isDebug) {
          val sentryLevel = SentryLevel.valueOf(it.toUpperCase(Locale.ROOT))
          options.setDiagnosticLevel(sentryLevel)
        }
      }
      args.getIfNotNull<Boolean>("anrEnabled") { options.isAnrEnabled = it }
      args.getIfNotNull<Boolean>("sendDefaultPii") { options.isSendDefaultPii = it }

      val nativeCrashHandling = (args["enableNativeCrashHandling"] as? Boolean) ?: true
      // nativeCrashHandling has priority over anrEnabled
      if (!nativeCrashHandling) {
        options.enableUncaughtExceptionHandler = false
        options.isAnrEnabled = false
        // if split symbols are enabled, we need Ndk integration so we can't really offer the option
        // to turn it off
        // options.isEnableNdk = false
      }

      options.setBeforeSend { event, _ ->
        setEventOriginTag(event)
        addPackages(event, options.sdkVersion)
        event
      }

      // missing proxy, enableScopeSync
    }
    result.success("")
  }

  private fun captureEnvelope(call: MethodCall, result: Result) {
    val args = call.arguments() as List<Any>? ?: listOf<Any>()
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

  private fun loadImageList(call: MethodCall, result: Result) {
    val options = HubAdapter.getInstance().options as SentryAndroidOptions

    val newDebugImages = mutableListOf<Map<String, Any?>>()
    val debugImages: List<DebugImage>? = options.debugImagesLoader.loadDebugImages()

    debugImages?.let {
      it.forEach { image ->
        val item = mutableMapOf<String, Any?>()

        item["image_addr"] = image.imageAddr
        item["image_size"] = image.imageSize
        item["code_file"] = image.codeFile
        item["type"] = image.type
        item["debug_id"] = image.debugId
        item["code_id"] = image.codeId
        item["debug_file"] = image.debugFile

        newDebugImages.add(item)
      }
    }

    result.success(newDebugImages)
  }

  private fun closeNativeSdk(result: Result) {
    Sentry.close()
    result.success("")
  }

  private val flutterSdk = "sentry.dart.flutter"
  private val androidSdk = "sentry.java.android"
  private val nativeSdk = "sentry.native"

  private fun setEventOriginTag(event: SentryEvent) {
    event.sdk?.let {
      when (it.name) {
        flutterSdk -> setEventEnvironmentTag(event, "flutter", "dart")
        androidSdk -> setEventEnvironmentTag(event, environment = "java")
        nativeSdk -> setEventEnvironmentTag(event, environment = "native")
        else -> return
      }
    }
  }

  private fun setEventEnvironmentTag(event: SentryEvent, origin: String = "android", environment: String) {
    event.setTag("event.origin", origin)
    event.setTag("event.environment", environment)
  }

  private fun addPackages(event: SentryEvent, sdk: SdkVersion?) {
    event.sdk?.let {
      if (it.name == flutterSdk) {
        sdk?.packages?.forEach { sentryPackage ->
          it.addPackage(sentryPackage.name, sentryPackage.version)
        }
        sdk?.integrations?.forEach { integration ->
          it.addIntegration(integration)
        }
      }
    }
  }
}

// Call the `completion` closure if cast to map value with `key` and type `T` is successful.
private fun <T> Map<String, Any>.getIfNotNull(key: String, callback: (T) -> Unit) {
  (get(key) as? T)?.let {
    callback(it)
  }
}
