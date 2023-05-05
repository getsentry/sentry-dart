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
import io.sentry.Breadcrumb
import io.sentry.HubAdapter
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.Sentry
import io.sentry.DateUtils
import io.sentry.android.core.ActivityFramesTracker
import io.sentry.android.core.AppStartState
import io.sentry.android.core.BuildConfig.VERSION_NAME
import io.sentry.android.core.LoadClass
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SdkVersion
import io.sentry.protocol.SentryId
import io.sentry.protocol.User
import io.sentry.protocol.Geo
import java.io.File
import java.lang.ref.WeakReference
import java.util.Locale
import java.util.UUID

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  private var activity: WeakReference<Activity>? = null
  private var framesTracker: ActivityFramesTracker? = null
  private var autoPerformanceTracingEnabled = false

  private val flutterSdk = "sentry.dart.flutter"
  private val androidSdk = "sentry.java.android.flutter"
  private val nativeSdk = "sentry.native.android"

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
      "setContexts" -> setContexts(call.argument("key"), call.argument("value"), result)
      "removeContexts" -> removeContexts(call.argument("key"), result)
      "setUser" -> setUser(call.argument("user"), result)
      "addBreadcrumb" -> addBreadcrumb(call.argument("breadcrumb"), result)
      "clearBreadcrumbs" -> clearBreadcrumbs(result)
      "setExtra" -> setExtra(call.argument("key"), call.argument("value"), result)
      "removeExtra" -> removeExtra(call.argument("key"), result)
      "setTag" -> setTag(call.argument("key"), call.argument("value"), result)
      "removeTag" -> removeTag(call.argument("key"), result)
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

    val args = call.arguments() as Map<String, Any>? ?: mapOf<String, Any>()
    if (args.isEmpty()) {
      result.error("4", "Arguments is null or empty", null)
      return
    }

    SentryAndroid.init(context) { options ->
      args.getIfNotNull<String>("dsn") { options.dsn = it }
      args.getIfNotNull<Boolean>("debug") { options.isDebug = it }
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
        options.isEnableUserInteractionBreadcrumbs = it
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
      args.getIfNotNull<String>("proguardUuid") { options.proguardUuid = it }

      val nativeCrashHandling = (args["enableNativeCrashHandling"] as? Boolean) ?: true
      // nativeCrashHandling has priority over anrEnabled
      if (!nativeCrashHandling) {
        options.isEnableUncaughtExceptionHandler = false
        options.isAnrEnabled = false
        // if split symbols are enabled, we need Ndk integration so we can't really offer the option
        // to turn it off
        // options.isEnableNdk = false
      }

      args.getIfNotNull<Boolean>("enableAutoPerformanceTracing") { enableAutoPerformanceTracing ->
        if (enableAutoPerformanceTracing) {
          autoPerformanceTracingEnabled = true
          framesTracker = ActivityFramesTracker(LoadClass(), options)
        }
      }

      args.getIfNotNull<Boolean>("sendClientReports") { options.isSendClientReports = it }

      args.getIfNotNull<Long>("maxAttachmentSize") { options.maxAttachmentSize = it }

      var sdkVersion = options.sdkVersion
      if (sdkVersion == null) {
        sdkVersion = SdkVersion(androidSdk, VERSION_NAME)
      } else {
        sdkVersion.name = androidSdk
      }

      options.sdkVersion = sdkVersion
      options.sentryClientName = "$androidSdk/$VERSION_NAME"

      options.setBeforeSend { event, _ ->
        setEventOriginTag(event)
        addPackages(event, options.sdkVersion)
        event
      }

      args.getIfNotNull<Int>("connectionTimeoutMillis") { options.connectionTimeoutMillis = it }
      args.getIfNotNull<Int>("readTimeoutMillis") { options.connectionTimeoutMillis = it }

      // missing proxy
    }
    result.success("")
  }

  private fun fetchNativeAppStart(result: Result) {
    if (!autoPerformanceTracingEnabled) {
      result.success(null)
      return
    }
    val appStartTime = AppStartState.getInstance().appStartTime
    val isColdStart = AppStartState.getInstance().isColdStart

    if (appStartTime == null) {
      Log.w("Sentry", "App start won't be sent due to missing appStartTime")
      result.success(null)
    } else if (isColdStart == null) {
      Log.w("Sentry", "App start won't be sent due to missing isColdStart")
      result.success(null)
    } else {
      val appStartTimeMillis = DateUtils.nanosToMillis(appStartTime.nanoTimestamp().toDouble())
      val item = mapOf<String, Any?>(
        "appStartTime" to appStartTimeMillis,
        "isColdStart" to isColdStart
      )
      result.success(item)
    }
  }

  private fun beginNativeFrames(result: Result) {
    if (!autoPerformanceTracingEnabled) {
      result.success(null)
      return
    }

    activity?.get()?.let {
      framesTracker?.addActivity(it)
    }
    result.success(null)
  }

  private fun endNativeFrames(id: String?, result: Result) {
    val activity = activity?.get()
    if (!autoPerformanceTracingEnabled || activity == null || id == null) {
      if (id == null) {
        Log.w("Sentry", "Parameter id cannot be null when calling endNativeFrames.")
      }
      result.success(null)
      return
    }

    val sentryId = SentryId(id)
    framesTracker?.setMetrics(activity, sentryId)
    val metrics = framesTracker?.takeMetrics(sentryId)
    val total = metrics?.get("frames_total")?.value?.toInt() ?: 0
    val slow = metrics?.get("frames_slow")?.value?.toInt() ?: 0
    val frozen = metrics?.get("frames_frozen")?.value?.toInt() ?: 0

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

  private fun setContexts(key: String?, value: Any?, result: Result) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.configureScope { scope ->
      scope.setContexts(key, value)

      result.success("")
    }
  }

  private fun removeContexts(key: String?, result: Result) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.configureScope { scope ->
      scope.removeContexts(key)

      result.success("")
    }
  }

  private fun setUser(user: Map<String, Any?>?, result: Result) {
    if (user == null) {
      Sentry.setUser(null)
      result.success("")
      return
    }

    val userInstance = User()
    val userData = mutableMapOf<String, String>()
    val unknown = mutableMapOf<String, Any>()

    (user["email"] as? String)?.let { userInstance.email = it }
    (user["id"] as? String)?.let { userInstance.id = it }
    (user["username"] as? String)?.let { userInstance.username = it }
    (user["ip_address"] as? String)?.let { userInstance.ipAddress = it }
    (user["segment"] as? String)?.let { userInstance.segment = it }
    (user["name"] as? String)?.let { userInstance.name = it }
    (user["geo"] as? Map<String, Any?>)?.let {
      val geo = Geo()
      geo.city = it["city"] as? String
      geo.countryCode = it["country_code"] as? String
      geo.region = it["region"] as? String
      userInstance.geo = geo
    }

    (user["extras"] as? Map<String, Any?>)?.let { extras ->
      for ((key, value) in extras.entries) {
        if (value != null) {
          userData[key] = value.toString()
        }
      }
    }
    (user["data"] as? Map<String, Any?>)?.let { data ->
      for ((key, value) in data.entries) {
        if (value != null) {
          // data has precedence over extras
          userData[key] = value.toString()
        }
      }
    }

    if (userData.isNotEmpty()) {
      userInstance.data = userData
    }
    if (unknown.isNotEmpty()) {
      userInstance.unknown = unknown
    }

    Sentry.setUser(userInstance)

    result.success("")
  }

  private fun addBreadcrumb(breadcrumb: Map<String, Any?>?, result: Result) {
    if (breadcrumb == null) {
      result.success("")
      return
    }
    val breadcrumbInstance = Breadcrumb()

    (breadcrumb["message"] as? String)?.let { breadcrumbInstance.message = it }
    (breadcrumb["type"] as? String)?.let { breadcrumbInstance.type = it }
    (breadcrumb["category"] as? String)?.let { breadcrumbInstance.category = it }
    (breadcrumb["level"] as? String)?.let {
      breadcrumbInstance.level = when (it) {
        "fatal" -> SentryLevel.FATAL
        "warning" -> SentryLevel.WARNING
        "info" -> SentryLevel.INFO
        "debug" -> SentryLevel.DEBUG
        "error" -> SentryLevel.ERROR
        else -> SentryLevel.INFO
      }
    }
    (breadcrumb["data"] as? Map<String, Any?>)?.let { data ->
      for ((key, value) in data.entries) {
        breadcrumbInstance.data[key] = value
      }
    }

    Sentry.addBreadcrumb(breadcrumbInstance)

    result.success("")
  }

  private fun clearBreadcrumbs(result: Result) {
    Sentry.clearBreadcrumbs()

    result.success("")
  }

  private fun setExtra(key: String?, value: String?, result: Result) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.setExtra(key, value)

    result.success("")
  }

  private fun removeExtra(key: String?, result: Result) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.removeExtra(key)

    result.success("")
  }

  private fun setTag(key: String?, value: String?, result: Result) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.setTag(key, value)

    result.success("")
  }

  private fun removeTag(key: String?, result: Result) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.removeTag(key)

    result.success("")
  }

  private fun captureEnvelope(call: MethodCall, result: Result) {
    val args = call.arguments() as List<Any>? ?: listOf<Any>()
    if (args.isNotEmpty()) {
      val event = args.first() as ByteArray?

      if (event != null && event.isNotEmpty()) {
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
    HubAdapter.getInstance().close()
    framesTracker?.stop()
    framesTracker = null

    result.success("")
  }

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
        sdk?.packageSet?.forEach { sentryPackage ->
          it.addPackage(sentryPackage.name, sentryPackage.version)
        }
        sdk?.integrationSet?.forEach { integration ->
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
