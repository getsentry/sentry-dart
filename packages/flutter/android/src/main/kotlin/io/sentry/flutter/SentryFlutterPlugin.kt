package io.sentry.flutter

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Looper
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
import io.sentry.ScopesAdapter
import io.sentry.Sentry
import io.sentry.android.core.InternalSentrySdk
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.android.core.performance.AppStartMetrics
import io.sentry.android.core.performance.TimeSpan
import io.sentry.android.replay.ReplayIntegration
import io.sentry.android.replay.ScreenshotRecorderConfig
import io.sentry.protocol.DebugImage
import io.sentry.protocol.User
import io.sentry.transport.CurrentDateProvider
import org.json.JSONObject
import org.json.JSONArray
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

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    pluginRegistrationTime = System.currentTimeMillis()

    context = flutterPluginBinding.applicationContext
    applicationContext = context
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
      "closeNativeSdk" -> closeNativeSdk(result)
      "setContexts" -> setContexts(call.argument("key"), call.argument("value"), result)
      "removeContexts" -> removeContexts(call.argument("key"), result)
      "setUser" -> setUser(call.argument("user"), result)
      "addBreadcrumb" -> addBreadcrumb(call.argument("breadcrumb"), result)
      "clearBreadcrumbs" -> clearBreadcrumbs(result)
      "setExtra" -> setExtra(call.argument("key"), call.argument("value"), result)
      "removeExtra" -> removeExtra(call.argument("key"), result)
      "setTag" -> setTag(call.argument("key"), call.argument("value"), result)
      "removeTag" -> removeTag(call.argument("key"), result)
      "setReplayConfig" -> setReplayConfig(call, result)
      "captureReplay" -> captureReplay(result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    if (!this::channel.isInitialized) {
      return
    }

    channel.setMethodCallHandler(null)
    applicationContext = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = WeakReference(binding.activity)
  }

  override fun onDetachedFromActivity() {
    activity = null
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
          replayCacheProvider = null,
        )
      replay!!.breadcrumbConverter = SentryFlutterReplayBreadcrumbConverter()
      options.addIntegration(replay!!)
      options.setReplayController(replay)
    } else {
      options.setReplayController(null)
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
      val options = ScopesAdapter.getInstance().options
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
      val options = ScopesAdapter.getInstance().options
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

  private fun closeNativeSdk(result: Result) {
    ScopesAdapter.getInstance().close()

    result.success("")
  }

  @Suppress("TooManyFunctions")
  companion object {
    @SuppressLint("StaticFieldLeak")
    private var replay: ReplayIntegration? = null

    @SuppressLint("StaticFieldLeak")
    private var applicationContext: Context? = null

    @SuppressLint("StaticFieldLeak")
    private var activity: WeakReference<Activity>? = null

    private var pluginRegistrationTime: Long? = null

    var autoPerformanceTracingEnabled: Boolean = false
      internal set

    private const val NATIVE_CRASH_WAIT_TIME = 500L

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun privateSentryGetReplayIntegration(): ReplayIntegration? = replay

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun nativeCrash() {
      val exception = RuntimeException("FlutterSentry Native Integration: Sample RuntimeException")
      val mainThread = Looper.getMainLooper().thread
      mainThread.uncaughtExceptionHandler?.uncaughtException(mainThread, exception)
      mainThread.join(NATIVE_CRASH_WAIT_TIME)
    }

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun getDisplayRefreshRate(): Int? {
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

      return refreshRate
    }

    @Suppress("unused", "ReturnCount") // Used by native/jni bindings
    @JvmStatic
    fun fetchNativeAppStartAsBytes(): ByteArray? {
      if (!autoPerformanceTracingEnabled) {
        return null
      }

      val appStartMetrics = AppStartMetrics.getInstance()

      if (!appStartMetrics.isAppLaunchedInForeground ||
        appStartMetrics.appStartTimeSpan.durationMs > APP_START_MAX_DURATION_MS
      ) {
        Log.w(
          "Sentry",
          "Invalid app start data: app not launched in foreground or app start took too long (>60s)",
        )
        return null
      }

      val appStartTimeSpan = appStartMetrics.appStartTimeSpan
      val appStartTime = appStartTimeSpan.startTimestamp
      val isColdStart = appStartMetrics.appStartType == AppStartMetrics.AppStartType.COLD

      if (appStartTime == null) {
        Log.w("Sentry", "App start won't be sent due to missing appStartTime")
        return null
      }

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
      addTimeSpanToMap(processInitSpan, androidNativeSpans)

      val applicationOnCreateSpan = appStartMetrics.applicationOnCreateTimeSpan
      addTimeSpanToMap(applicationOnCreateSpan, androidNativeSpans)

      val contentProviderSpans = appStartMetrics.contentProviderOnCreateTimeSpans
      contentProviderSpans.forEach { span ->
        addTimeSpanToMap(span, androidNativeSpans)
      }

      appStartMetrics.activityLifecycleTimeSpans.forEach { span ->
        addTimeSpanToMap(span.onCreate, androidNativeSpans)
        addTimeSpanToMap(span.onStart, androidNativeSpans)
      }

      item["nativeSpanTimes"] = androidNativeSpans

      val json = JSONObject(item).toString()
      return json.toByteArray(Charsets.UTF_8)
    }

    private fun addTimeSpanToMap(
      span: TimeSpan,
      map: MutableMap<String, Any?>,
    ) {
      if (span.startTimestamp == null) return

      span.description?.let { description ->
        map[description] =
          mapOf<String, Any?>(
            "startTimestampMsSinceEpoch" to span.startTimestampMs,
            "stopTimestampMsSinceEpoch" to span.projectedStopTimestampMs,
          )
      }
    }

    @JvmStatic
    fun getApplicationContext(): Context? = applicationContext

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun loadContextsAsBytes(): ByteArray? {
      val options = ScopesAdapter.getInstance().options
      val context = getApplicationContext()
      if (options !is SentryAndroidOptions || context == null) {
        return null
      }
      val currentScope = InternalSentrySdk.getCurrentScope()
      val serializedScope =
        InternalSentrySdk.serializeScope(
          context,
          options,
          currentScope,
        )
      val json = JSONObject(serializedScope).toString()
      return json.toByteArray(Charsets.UTF_8)
    }

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun loadDebugImagesAsBytes(addresses: Set<String>): ByteArray? {
      val options = ScopesAdapter.getInstance().options as SentryAndroidOptions

      val debugImages =
        if (addresses.isEmpty()) {
          options.debugImagesLoader
            .loadDebugImages()
            ?.toList()
            .serialize()
        } else {
          options.debugImagesLoader
            .loadDebugImagesForAddresses(addresses)
            ?.ifEmpty { options.debugImagesLoader.loadDebugImages() }
            ?.toList()
            .serialize()
        }

      val json = JSONArray(debugImages).toString()
      return json.toByteArray(Charsets.UTF_8)
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

    private fun Double.adjustReplaySizeToBlockSize(): Double {
      val remainder = this % VIDEO_BLOCK_SIZE
      return if (remainder <= VIDEO_BLOCK_SIZE / 2) {
        this - remainder
      } else {
        this + (VIDEO_BLOCK_SIZE - remainder)
      }
    }
  }

  private fun setReplayConfig(
    call: MethodCall,
    result: Result,
  ) {
    // Since codec block size is 16, so we have to adjust the width and height to it,
    // otherwise the codec might fail to configure on some devices, see
    // https://cs.android.com/android/platform/superproject/+/master:frameworks/base/media/java/android/media/MediaCodecInfo.java;l=1999-2001
    val windowWidth = call.argument("windowWidth") as? Double ?: 0.0
    val windowHeight = call.argument("windowHeight") as? Double ?: 0.0

    var width = call.argument("width") as? Double ?: 0.0
    var height = call.argument("height") as? Double ?: 0.0

    val invalidConfig =
      width == 0.0 ||
        height == 0.0 ||
        windowWidth == 0.0 ||
        windowHeight == 0.0

    if (invalidConfig) {
      result.error(
        "5",
        "Replay config is not valid: width: $width, height: $height, " +
          "windowWidth: $windowWidth, windowHeight: $windowHeight",
        null,
      )
      return
    }

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

    val replayConfig =
      ScreenshotRecorderConfig(
        recordingWidth = width.roundToInt(),
        recordingHeight = height.roundToInt(),
        scaleFactorX = width.toFloat() / windowWidth.toFloat(),
        scaleFactorY = height.toFloat() / windowHeight.toFloat(),
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
    replay?.onConfigurationChanged(replayConfig)
    result.success("")
  }

  private fun captureReplay(
    result: Result,
  ) {
    replay!!.captureReplay(isTerminating = false)
    result.success(replay!!.getReplayId().toString())
  }
}
