package io.sentry.flutter

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.graphics.Point
import android.graphics.Rect
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.sentry.Breadcrumb
import io.sentry.DateUtils
import io.sentry.HubAdapter
import io.sentry.Sentry
import io.sentry.android.core.ActivityFramesTracker
import io.sentry.android.core.InternalSentrySdk
import io.sentry.android.core.LoadClass
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.android.core.performance.AppStartMetrics
import io.sentry.android.core.performance.TimeSpan
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SentryId
import io.sentry.protocol.User
import io.sentry.transport.CurrentDateProvider
import java.lang.ref.WeakReference
import kotlin.math.roundToInt

private const val APP_START_MAX_DURATION_MS = 60000
public const val VIDEO_BLOCK_SIZE = 16

class SentryFlutterPlugin :
  FlutterPlugin,
  MethodCallHandler,
  ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var sentryFlutter: SentryFlutter

  // Note: initial config because we don't yet have the numbers of the actual Flutter widget.
  // See how SentryFlutterReplayRecorder.start() handles it. New settings will be set by setReplayConfig() method below.
  private var replayConfig =
    ScreenshotRecorderConfig(
      recordingWidth = VIDEO_BLOCK_SIZE,
      recordingHeight = VIDEO_BLOCK_SIZE,
      scaleFactorX = 1.0f,
      scaleFactorY = 1.0f,
      frameRate = 1,
      bitRate = 75000,
    )

  private var activity: WeakReference<Activity>? = null
  private var framesTracker: ActivityFramesTracker? = null
  private var pluginRegistrationTime: Long? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    pluginRegistrationTime = System.currentTimeMillis()

    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sentry_flutter")
    channel.setMethodCallHandler(this)

    sentryFlutter = SentryFlutter()
  }

  @Suppress("CyclomaticComplexMethod")
  override fun onMethodCall(
    call: MethodCall,
    result: Result,
  ) {
    when (call.method) {
      "initNativeSdk" -> initNativeSdk(call, result)
      "captureEnvelope" -> captureEnvelope(call, result)
      "loadImageList" -> loadImageList(call, result)
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
      "nativeCrash" -> crash()
      "setReplayConfig" -> setReplayConfig(call, result)
      "captureReplay" -> captureReplay(call.argument("isCrash"), result)
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

  private fun initNativeSdk(
    call: MethodCall,
    result: Result,
  ) {
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

      setupReplay(options)
    }
    result.success("")
  }

  private fun setupReplay(options: SentryAndroidOptions) {
    // Replace the default ReplayIntegration with a Flutter-specific recorder.
    options.integrations.removeAll { it is ReplayIntegration }
    val replayOptions = options.sessionReplay
    if (replayOptions.isSessionReplayEnabled || replayOptions.isSessionReplayForErrorsEnabled) {
      replay =
        ReplayIntegration(
          context.applicationContext,
          dateProvider = CurrentDateProvider.getInstance(),
          recorderProvider = { SentryFlutterReplayRecorder(channel, replay!!) },
          recorderConfigProvider = {
            Log.i(
              "Sentry",
              "Replay configuration requested. Returning: %dx%d at %d FPS, %d BPS".format(
                replayConfig.recordingWidth,
                replayConfig.recordingHeight,
                replayConfig.frameRate,
                replayConfig.bitRate,
              ),
            )
            replayConfig
          },
          replayCacheProvider = null,
        )
      replay!!.breadcrumbConverter = SentryFlutterReplayBreadcrumbConverter()
      options.addIntegration(replay!!)
      options.setReplayController(replay)
    } else {
      options.setReplayController(null)
    }
  }

  private fun fetchNativeAppStart(result: Result) {
    if (!sentryFlutter.autoPerformanceTracingEnabled) {
      result.success(null)
      return
    }

    val appStartMetrics = AppStartMetrics.getInstance()

    if (!appStartMetrics.isAppLaunchedInForeground ||
      appStartMetrics.appStartTimeSpan.durationMs > APP_START_MAX_DURATION_MS
    ) {
      Log.w(
        "Sentry",
        "Invalid app start data: app not launched in foreground or app start took too long (>60s)",
      )
      result.success(null)
      return
    }

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

  private fun endNativeFrames(
    id: String?,
    result: Result,
  ) {
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
      val frames =
        mapOf<String, Any?>(
          "totalFrames" to total,
          "slowFrames" to slow,
          "frozenFrames" to frozen,
        )
      result.success(frames)
    }
  }

  private fun setContexts(
    key: String?,
    value: Any?,
    result: Result,
  ) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.configureScope { scope ->
      scope.setContexts(key, value)

      result.success("")
    }
  }

  private fun removeContexts(
    key: String?,
    result: Result,
  ) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.configureScope { scope ->
      scope.removeContexts(key)

      result.success("")
    }
  }

  private fun setUser(
    user: Map<String, Any?>?,
    result: Result,
  ) {
    if (user != null) {
      val options = HubAdapter.getInstance().options
      val userInstance = User.fromMap(user, options)
      Sentry.setUser(userInstance)
    } else {
      Sentry.setUser(null)
    }
    result.success("")
  }

  private fun addBreadcrumb(
    breadcrumb: Map<String, Any?>?,
    result: Result,
  ) {
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

  private fun setExtra(
    key: String?,
    value: String?,
    result: Result,
  ) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.setExtra(key, value)

    result.success("")
  }

  private fun removeExtra(
    key: String?,
    result: Result,
  ) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.removeExtra(key)

    result.success("")
  }

  private fun setTag(
    key: String?,
    value: String?,
    result: Result,
  ) {
    if (key == null || value == null) {
      result.success("")
      return
    }
    Sentry.setTag(key, value)

    result.success("")
  }

  private fun removeTag(
    key: String?,
    result: Result,
  ) {
    if (key == null) {
      result.success("")
      return
    }
    Sentry.removeTag(key)

    result.success("")
  }

  private fun captureEnvelope(
    call: MethodCall,
    result: Result,
  ) {
    if (!Sentry.isEnabled()) {
      result.error("1", "The Sentry Android SDK is disabled", null)
      return
    }
    val args = call.arguments() as List<Any>? ?: listOf()
    if (args.isNotEmpty()) {
      val event = args.first() as ByteArray?
      val containsUnhandledException = args[1] as Boolean
      if (event != null && event.isNotEmpty()) {
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

  private fun loadImageList(
    call: MethodCall,
    result: Result,
  ) {
    val options = HubAdapter.getInstance().options as SentryAndroidOptions

    val addresses = call.arguments() as List<String>? ?: listOf()
    val debugImages =
      if (addresses.isEmpty()) {
        options.debugImagesLoader
          .loadDebugImages()
          ?.toList()
          .serialize()
      } else {
        options.debugImagesLoader
          .loadDebugImagesForAddresses(addresses.toSet())
          ?.ifEmpty { options.debugImagesLoader.loadDebugImages() }
          ?.toList()
          .serialize()
      }

    result.success(debugImages)
  }

  private fun List<DebugImage>?.serialize() = this?.map { it.serialize() }

  private fun DebugImage.serialize() =
    mapOf(
      "image_addr" to imageAddr,
      "image_size" to imageSize,
      "code_file" to codeFile,
      "type" to type,
      "debug_id" to debugId,
      "code_id" to codeId,
      "debug_file" to debugFile,
    )

  private fun closeNativeSdk(result: Result) {
    HubAdapter.getInstance().close()
    framesTracker?.stop()
    framesTracker = null

    result.success("")
  }

  companion object {
    @SuppressLint("StaticFieldLeak")
    private var replay: ReplayIntegration? = null

    private const val NATIVE_CRASH_WAIT_TIME = 500L

    @JvmStatic fun privateSentryGetReplayIntegration(): ReplayIntegration? = replay

    private fun crash() {
      val exception = RuntimeException("FlutterSentry Native Integration: Sample RuntimeException")
      val mainThread = Looper.getMainLooper().thread
      mainThread.uncaughtExceptionHandler.uncaughtException(mainThread, exception)
      mainThread.join(NATIVE_CRASH_WAIT_TIME)
    }

    private fun Double.adjustReplaySizeToBlockSize(): Double {
      val remainder = this % VIDEO_BLOCK_SIZE
      return if (remainder <= VIDEO_BLOCK_SIZE / 2) {
        this - remainder
      } else {
        this + (VIDEO_BLOCK_SIZE - remainder)
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

  private fun setReplayConfig(
    call: MethodCall,
    result: Result,
  ) {
    // Since codec block size is 16, so we have to adjust the width and height to it,
    // otherwise the codec might fail to configure on some devices, see
    // https://cs.android.com/android/platform/superproject/+/master:frameworks/base/media/java/android/media/MediaCodecInfo.java;l=1999-2001
    var width = call.argument("width") as? Double ?: 0.0
    var height = call.argument("height") as? Double ?: 0.0
    // First update the smaller dimension, as changing that will affect the screen ratio more.
    if (width < height) {
      val newWidth = width.adjustReplaySizeToBlockSize()
      height = (height * (newWidth / width)).adjustReplaySizeToBlockSize()
      width = newWidth
    } else {
      val newHeight = height.adjustReplaySizeToBlockSize()
      width = (width * (newHeight / height)).adjustReplaySizeToBlockSize()
      height = newHeight
    }

    val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    val screenBounds =
      if (VERSION.SDK_INT >= VERSION_CODES.R) {
        wm.currentWindowMetrics.bounds
      } else {
        val screenBounds = Point()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealSize(screenBounds)
        Rect(0, 0, screenBounds.x, screenBounds.y)
      }

    replayConfig =
      ScreenshotRecorderConfig(
        recordingWidth = width.roundToInt(),
        recordingHeight = height.roundToInt(),
        scaleFactorX = width.toFloat() / screenBounds.width().toFloat(),
        scaleFactorY = height.toFloat() / screenBounds.height().toFloat(),
        frameRate = call.argument("frameRate") as? Int ?: 0,
        bitRate = call.argument("bitRate") as? Int ?: 0,
      )
    Log.i(
      "Sentry",
      "Configuring replay: %dx%d at %d FPS, %d BPS".format(
        replayConfig.recordingWidth,
        replayConfig.recordingHeight,
        replayConfig.frameRate,
        replayConfig.bitRate,
      ),
    )
    replay!!.onConfigurationChanged(Configuration())
    result.success("")
  }

  private fun captureReplay(
    isCrash: Boolean?,
    result: Result,
  ) {
    if (isCrash == null) {
      result.error("5", "Arguments are null", null)
      return
    }
    replay!!.captureReplay(isCrash)
    result.success(replay!!.getReplayId().toString())
  }
}
