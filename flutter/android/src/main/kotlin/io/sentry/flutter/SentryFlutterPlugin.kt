package io.sentry.flutter

import android.app.Activity
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.sentry.HubAdapter
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.android.core.ActivityFramesTracker
import io.sentry.android.core.AppStartState
import io.sentry.android.core.LoadClass
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SdkVersion
import io.sentry.protocol.SentryId
import java.io.File
import java.lang.ref.WeakReference
import java.util.Locale
import java.util.UUID

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  private var activity: WeakReference<Activity>? = null
  private var framesTracker: ActivityFramesTracker? = null
  private var autoPerformanceTrackingEnabled = false

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initNativeSdk" -> initNativeSdk(call, result)
      "captureEnvelope" -> captureEnvelope(call, result)
      "loadImageList" -> loadImageList(result)
      "closeNativeSdk" -> closeNativeSdk(result)
      "fetchNativeAppStart" -> fetchNativeAppStart(result)
      "beginNativeFrames" -> beginNativeFrames(result)
      "endNativeFrames" -> endNativeFrames(call.argument("id"), result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    if (!this::channel.isInitialized) {
      return
    }

    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = WeakReference(binding.activity)
  }

  override fun onDetachedFromActivity() {
    activity = null
    framesTracker = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    // Stub
  }

  override fun onDetachedFromActivityForConfigChanges() {
    // Stub
  }

  private fun writeEnvelope(envelope: ByteArray): Boolean {
    val options = HubAdapter.getInstance().options
    if (options.outboxPath.isNullOrEmpty()) {
      return false
    }

    val file = File(options.outboxPath, UUID.randomUUID().toString())
    file.writeBytes(envelope)

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
      args.getIfNotNull<Int>("maxCacheItems") { options.maxCacheItems = it }
      args.getIfNotNull<String>("diagnosticLevel") {
        if (options.isDebug) {
          val sentryLevel = SentryLevel.valueOf(it.toUpperCase(Locale.ROOT))
          options.setDiagnosticLevel(sentryLevel)
        }
      }
      args.getIfNotNull<Boolean>("anrEnabled") { options.isAnrEnabled = it }
      args.getIfNotNull<Boolean>("sendDefaultPii") { options.isSendDefaultPii = it }
      args.getIfNotNull<Boolean>("enableNdkScopeSync") { options.isEnableScopeSync = it }

      val nativeCrashHandling = (args["enableNativeCrashHandling"] as? Boolean) ?: true
      // nativeCrashHandling has priority over anrEnabled
      if (!nativeCrashHandling) {
        options.enableUncaughtExceptionHandler = false
        options.isAnrEnabled = false
        // if split symbols are enabled, we need Ndk integration so we can't really offer the option
        // to turn it off
        // options.isEnableNdk = false
      }

      args.getIfNotNull<Boolean>("enableAutoPerformanceTracking") { enableAutoPerformanceTracking ->
        if (enableAutoPerformanceTracking) {
          autoPerformanceTrackingEnabled = true
          framesTracker = ActivityFramesTracker(LoadClass())
        }
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

  private fun fetchNativeAppStart(result: Result) {
    if (!autoPerformanceTrackingEnabled) {
      result.success(null)
      return
    }
    val appStartTime = AppStartState.getInstance().getAppStartTime()
    val isColdStart = AppStartState.getInstance().isColdStart()

    if (appStartTime == null) {
      Log.w("Sentry", "App start won't be sent due to missing appStartTime")
      result.success(null)
    } else if (isColdStart == null) {
      Log.w("Sentry", "App start won't be sent due to missing isColdStart")
      result.success(null)
    } else {
      val item = mapOf<String, Any?>(
        "appStartTime" to appStartTime.getTime().toDouble(),
        "isColdStart" to isColdStart
      )
      result.success(item)
    }
  }

  private fun beginNativeFrames(result: Result) {
    if (!autoPerformanceTrackingEnabled) {
      result.success(null)
      return
    }

    activity?.get()?.let {
      framesTracker?.addActivity(it)
    }
    result.success(null)
  }

  private fun endNativeFrames(id: String?, result: Result) {
    if (!autoPerformanceTrackingEnabled) {
      result.success(null)
      return
    }
    if (id == null) {
      Log.w("Sentry", "Parameter id cannot be null when calling endNativeFrames.")
      result.success(null)
      return
    }

    val activity = activity?.get()

    if (activity == null) {
      result.success(null)
      return
    }

    val sentryId = SentryId(id)
    framesTracker?.setMetrics(activity, sentryId)
    val metrics = framesTracker?.takeMetrics(sentryId)
    val total = metrics?.get("frames_total")?.getValue()?.toInt() ?: 0
    val slow = metrics?.get("frames_slow")?.getValue()?.toInt() ?: 0
    val frozen = metrics?.get("frames_frozen")?.getValue()?.toInt() ?: 0

    if (total == 0 && slow == 0 && frozen == 0) {
      result.success(null)
    } else {
      val frames = mapOf<String, Any?>(
        "totalFrames" to total,
        "slowFrames" to slow,
        "frozenFrames" to frozen
      )
      result.success(frames)
    }
  }

  private fun captureEnvelope(call: MethodCall, result: Result) {
    val args = call.arguments() as List<Any>
    if (args.isNotEmpty()) {
      val event = args.first() as ByteArray?

      if (event != null && event.size > 0) {
        if (!writeEnvelope(event)) {
          result.error("3", "SentryOptions or outboxPath are null or empty", null)
        }
        result.success("")
        return
      }
    }

    result.error("2", "Envelope is null or empty", null)
  }

  private fun loadImageList(result: Result) {
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
    framesTracker?.stop()
    framesTracker = null

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
