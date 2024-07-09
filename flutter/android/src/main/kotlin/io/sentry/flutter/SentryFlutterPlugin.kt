package io.sentry.flutter

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.sentry.Breadcrumb
import io.sentry.DateUtils
import io.sentry.Hint
import io.sentry.HubAdapter
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryOptions
import io.sentry.android.core.ActivityFramesTracker
import io.sentry.android.core.InternalSentrySdk
import io.sentry.android.core.LoadClass
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.android.core.performance.AppStartMetrics
import io.sentry.android.core.performance.TimeSpan
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SdkVersion
import io.sentry.protocol.SentryId
import io.sentry.protocol.User
import java.lang.ref.WeakReference

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var sentryFlutter: SentryFlutter

  private var activity: WeakReference<Activity>? = null
  private var framesTracker: ActivityFramesTracker? = null
  private var pluginRegistrationTime: Long? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    pluginRegistrationTime = System.currentTimeMillis()

    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)

    sentryFlutter =
      SentryFlutter(
        androidSdk = androidSdk,
        nativeSdk = nativeSdk,
      )
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
      "loadContexts" -> loadContexts(result)
      "displayRefreshRate" -> displayRefreshRate(result)
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
      sentryFlutter.updateOptions(options, args)

      if (sentryFlutter.autoPerformanceTracingEnabled) {
        framesTracker = ActivityFramesTracker(LoadClass(), options)
      }

      options.beforeSend = BeforeSendCallbackImpl(options.sdkVersion)
    }
    result.success("")
  }

  private fun fetchNativeAppStart(result: Result) {
    if (!sentryFlutter.autoPerformanceTracingEnabled) {
      result.success(null)
      return
    }

    val appStartMetrics = AppStartMetrics.getInstance()

    val appStartTimeSpan = appStartMetrics.appStartTimeSpan
    val appStartTime = appStartTimeSpan.startTimestamp
    val isColdStart = appStartMetrics.appStartType == AppStartMetrics.AppStartType.COLD

    if (appStartTime == null) {
      Log.w("Sentry", "App start won't be sent due to missing appStartTime")
      result.success(null)
    } else {
      val appStartTimeMillis = DateUtils.nanosToMillis(appStartTime.nanoTimestamp().toDouble())
      val item =
        mutableMapOf<String, Any?>(
          "pluginRegistrationTime" to pluginRegistrationTime,
          "appStartTime" to appStartTimeMillis,
          "isColdStart" to isColdStart,
        )

      val androidNativeSpans = mutableMapOf<String, Any?>()

      val processInitSpan =
        TimeSpan().apply {
          description = "Process Initialization"
          setStartUnixTimeMs(appStartTimeSpan.startTimestampMs)
          setStartedAt(appStartTimeSpan.startUptimeMs)
          setStoppedAt(appStartMetrics.classLoadedUptimeMs)
        }
      processInitSpan.addToMap(androidNativeSpans)

      val applicationOnCreateSpan = appStartMetrics.applicationOnCreateTimeSpan
      applicationOnCreateSpan.addToMap(androidNativeSpans)

      val contentProviderSpans = appStartMetrics.contentProviderOnCreateTimeSpans
      contentProviderSpans.forEach { span ->
        span.addToMap(androidNativeSpans)
      }

      appStartMetrics.activityLifecycleTimeSpans.forEach { span ->
        span.onCreate.addToMap(androidNativeSpans)
        span.onStart.addToMap(androidNativeSpans)
      }

      item["nativeSpanTimes"] = androidNativeSpans

      result.success(item)
    }
  }

  private fun displayRefreshRate(result: Result) {
    var refreshRate: Int? = null

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      val display = activity?.get()?.display
      if (display != null) {
        refreshRate = display.refreshRate.toInt()
      }
    } else {
      val display =
        activity
          ?.get()
          ?.window
          ?.windowManager
          ?.defaultDisplay
      if (display != null) {
        refreshRate = display.refreshRate.toInt()
      }
    }

    result.success(refreshRate)
  }

  private fun TimeSpan.addToMap(map: MutableMap<String, Any?>) {
    if (startTimestamp == null) return

    description?.let { description ->
      map[description] =
        mapOf<String, Any?>(
          "startTimestampMsSinceEpoch" to startTimestampMs,
          "stopTimestampMsSinceEpoch" to projectedStopTimestampMs,
        )
    }
  }

  private fun beginNativeFrames(result: Result) {
    if (!sentryFlutter.autoPerformanceTracingEnabled) {
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
    if (!sentryFlutter.autoPerformanceTracingEnabled || activity == null || id == null) {
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
        "frozenFrames" to frozen,
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
    if (user != null) {
      val options = HubAdapter.getInstance().options
      val userInstance = User.fromMap(user, options)
      Sentry.setUser(userInstance)
    } else {
      Sentry.setUser(null)
    }
    result.success("")
  }

  private fun addBreadcrumb(breadcrumb: Map<String, Any?>?, result: Result) {
    if (breadcrumb != null) {
      val options = HubAdapter.getInstance().options
      val breadcrumbInstance = Breadcrumb.fromMap(breadcrumb, options)
      Sentry.addBreadcrumb(breadcrumbInstance)
    }
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
    if (!Sentry.isEnabled()) {
      result.error("1", "The Sentry Android SDK is disabled", null)
      return
    }
    val args = call.arguments() as List<Any>? ?: listOf()
    if (args.isNotEmpty()) {
      val event = args.first() as ByteArray?
      val containsUnhandledException = args[1] as Boolean
      if (event != null && event.isNotEmpty() && containsUnhandledException != null) {
        val id = InternalSentrySdk.captureEnvelope(event, containsUnhandledException)
        if (id != null) {
          result.success("")
        } else {
          result.error("2", "Failed to capture envelope", null)
        }
        return
      }
    }
    result.error("3", "Envelope is null or empty", null)
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

  private class BeforeSendCallbackImpl(
    private val sdkVersion: SdkVersion?,
  ) : SentryOptions.BeforeSendCallback {
    override fun execute(event: SentryEvent, hint: Hint): SentryEvent {
      setEventOriginTag(event)
      addPackages(event, sdkVersion)
      return event
    }
  }

  companion object {

    private const val flutterSdk = "sentry.dart.flutter"
    private const val androidSdk = "sentry.java.android.flutter"
    private const val nativeSdk = "sentry.native.android.flutter"
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

    private fun setEventEnvironmentTag(
      event: SentryEvent,
      origin: String = "android",
      environment: String,
    ) {
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

  private fun loadContexts(result: Result) {
    val options = HubAdapter.getInstance().options
    if (options !is SentryAndroidOptions) {
      result.success(null)
      return
    }
    val currentScope = InternalSentrySdk.getCurrentScope()
    val serializedScope =
      InternalSentrySdk.serializeScope(
        context,
        options,
        currentScope,
      )
    result.success(serializedScope)
  }
}
