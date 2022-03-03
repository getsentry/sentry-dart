package io.sentry.flutter

import android.app.Activity
import android.content.Context
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
import io.sentry.android.core.AppStartState
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.DebugImage
import io.sentry.protocol.SdkVersion
import java.io.File
import java.util.Locale
import java.util.UUID
import androidx.core.app.FrameMetricsAggregator;

class SentryFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  // TODO Check if we should read display framerate and calculate accordingly.

  // 700ms to constitute frozen frames.
  private val frozenFrameThreshold = 700
  // 16ms (slower than 60fps) to constitute slow frames.
  private val slowFrameThreshold = 16

  private var activity: Activity? = null
  private var frameMetricsAggregator: FrameMetricsAggregator? = null

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
      "fetchNativeFrames" -> fetchNativeFrames(result)
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
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    // Stub
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

      options.setBeforeSend { event, _ ->
        setEventOriginTag(event)
        addPackages(event, options.sdkVersion)
        event
      }

      // missing proxy, enableScopeSync
    }

    // TODO: Only enable if auto is enabled
    isFrameMetricsAggregatorEnabled = enableFrameMetricsAggregator()

    result.success("")
  }

  private fun fetchNativeAppStart(result: Result) {
    val appStartTime = AppStartState.getInstance().getAppStartTime()
    val isColdStart = AppStartState.getInstance().isColdStart()

    if (appStartTime == null) {
      result.error("1", "App start won't be sent due to missing appStartTime", null)
    } else if (isColdStart == null) {
      result.error("1", "App start won't be sent due to missing isColdStart", null)
    } else {
      val item = mapOf<String, Any?>(
        "appStartTime" to appStartTime.getTime().toDouble(),
        "isColdStart" to isColdStart
      )
      result.success(item)
    }
  }

  private fun fetchNativeFrames(result: Result) {
    if (!isFrameMetricsAggregatorEnabled) {
      result.error("1", "Native frames not available.", null)
      return
    }

    try {
      var totalFrames = 0
      var slowFrames = 0
      var frozenFrames = 0

      val framesRates = frameMetricsAggregator?.getMetrics()
      if (framesRates != null) {
        val totalIndexArray = framesRates[FrameMetricsAggregator.TOTAL_INDEX]
        if (totalIndexArray != null) {
          for (i in 0 until totalIndexArray.size()) {
            val frameTime: Int = totalIndexArray.keyAt(i)
            val numFrames: Int = totalIndexArray.valueAt(i)
            totalFrames += numFrames

            // Hard coded values, its also in the official android docs and frame metrics API.
            if (frameTime > frozenFrameThreshold) {
              // frozen frames, threshold is 700ms
              frozenFrames += numFrames
            } else if (frameTime > slowFrameThreshold) {
              // slow frames, above 16ms, 60 frames/second
              slowFrames += numFrames;
            }
          }
        }
      }

      val item = mapOf<String, Any?>(
        "totalFrames" to totalFrames,
        "slowFrames" to slowFrames,
        "frozenFrames" to frozenFrames,
      )

      result.success(item)
    } catch (ignored: Exception) {
      result.error("1", "Error fetching native frames.", "${ignored}")
    }
  }

  private fun isFrameMetricsAggregatorAvailable(): Boolean {
    return try {
      Class.forName("androidx.core.app.FrameMetricsAggregator")
      true
    } catch (ignored: Exception) {
      false // androidx.core isn't available.
    }
  }

  private var isFrameMetricsAggregatorEnabled = false

  private fun enableFrameMetricsAggregator(): Boolean {
    if (!isFrameMetricsAggregatorAvailable()) {
      return false
    }
    val frameMetricsAggregator = FrameMetricsAggregator() ?: return false
    val currentActivity = activity ?: return false

    return try {
      frameMetricsAggregator.add(currentActivity)
      this.frameMetricsAggregator = frameMetricsAggregator
      true
    } catch (ignored: Exception) {
      // throws ConcurrentModification when calling addOnFrameMetricsAvailableListener
      // this is a best effort since we can't reproduce it
      false
    }
  }

  private fun diableFrameMetricsAggregator() {
    frameMetricsAggregator?.stop()
    frameMetricsAggregator = null
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
    diableFrameMetricsAggregator()

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
