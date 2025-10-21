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

    private lateinit var sentryFlutter: SentryFlutter

    private const val NATIVE_CRASH_WAIT_TIME = 500L

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun privateSentryGetReplayIntegration(): ReplayIntegration? = replay

    @Suppress("unused") // Used by native/jni bindings
    @JvmStatic
    fun crash() {
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

    @Suppress("unused", "ReturnCount", "TooGenericExceptionCaught") // Used by native/jni bindings
    @JvmStatic
    fun fetchNativeAppStartAsBytes(): ByteArray? {
      if (!sentryFlutter.autoPerformanceTracingEnabled) {
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

    @Suppress("unused", "ReturnCount", "TooGenericExceptionCaught") // Used by native/jni bindings
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
      try {
        val json = JSONObject(serializedScope).toString()
        return json.toByteArray(Charsets.UTF_8)
      } catch (e: Exception) {
        Log.e("Sentry", "Failed to serialize scope", e)
        return null
      }
    }

    @Suppress("unused", "TooGenericExceptionCaught") // Used by native/jni bindings
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

      try {
        val json = JSONArray(debugImages).toString()
        return json.toByteArray(Charsets.UTF_8)
      } catch (e: Exception) {
        Log.e("Sentry", "Failed to serialize debug images", e)
        return null
      }
    }

    @JvmStatic
    fun setReplayConfig(
      windowWidth: Double,
      windowHeight: Double,
      width: Double,
      height: Double,
      frameRate: Int,
      bitRate: Int,
    ) {
      // Since codec block size is 16, so we have to adjust the width and height to it,
      // otherwise the codec might fail to configure on some devices, see
      // https://cs.android.com/android/platform/superproject/+/master:frameworks/base/media/java/android/media/MediaCodecInfo.java;l=1999-2001
      val invalidConfig =
        width == 0.0 ||
          height == 0.0 ||
          windowWidth == 0.0 ||
          windowHeight == 0.0

      if (invalidConfig) {
        Log.e(
          "Sentry",
          "Replay config is not valid: width: $width, height: $height, " +
            "windowWidth: $windowWidth, windowHeight: $windowHeight",
        )
        return
      }

      var adjWidth = width
      var adjHeight = height

      // First update the smaller dimension, as changing that will affect the screen ratio more.
      if (adjWidth < adjHeight) {
        val newWidth = adjWidth.adjustReplaySizeToBlockSize()
        val scale = newWidth / adjWidth
        val newHeight = (adjHeight * scale).adjustReplaySizeToBlockSize()
        adjWidth = newWidth
        adjHeight = newHeight
      } else {
        val newHeight = adjHeight.adjustReplaySizeToBlockSize()
        val scale = newHeight / adjHeight
        val newWidth = (adjWidth * scale).adjustReplaySizeToBlockSize()
        adjHeight = newHeight
        adjWidth = newWidth
      }

      val replayConfig =
        ScreenshotRecorderConfig(
          recordingWidth = adjWidth.roundToInt(),
          recordingHeight = adjHeight.roundToInt(),
          scaleFactorX = adjWidth.toFloat() / windowWidth.toFloat(),
          scaleFactorY = adjHeight.toFloat() / windowHeight.toFloat(),
          frameRate = frameRate,
          bitRate = bitRate,
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
}
