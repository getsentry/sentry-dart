package io.sentry.flutter

import android.util.Log
import io.sentry.SentryLevel
import io.sentry.SentryOptions.Proxy
import io.sentry.SentryReplayOptions
import io.sentry.android.core.BuildConfig
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.SdkVersion
import java.net.Proxy.Type
import java.util.Locale

class SentryFlutter(
  private val androidSdk: String,
  private val nativeSdk: String,
) {
  var autoPerformanceTracingEnabled = false

  fun updateOptions(
    options: SentryAndroidOptions,
    data: Map<String, Any>,
  ) {
    data.getIfNotNull<String>("dsn") {
      options.dsn = it
    }
    data.getIfNotNull<Boolean>("debug") {
      options.isDebug = it
    }
    data.getIfNotNull<String>("environment") {
      options.environment = it
    }
    data.getIfNotNull<String>("release") {
      options.release = it
    }
    data.getIfNotNull<String>("dist") {
      options.dist = it
    }
    data.getIfNotNull<Boolean>("enableAutoSessionTracking") {
      options.isEnableAutoSessionTracking = it
    }
    data.getIfNotNull<Long>("autoSessionTrackingIntervalMillis") {
      options.sessionTrackingIntervalMillis = it
    }
    data.getIfNotNull<Long>("anrTimeoutIntervalMillis") {
      options.anrTimeoutIntervalMillis = it
    }
    data.getIfNotNull<Boolean>("attachThreads") {
      options.isAttachThreads = it
    }
    data.getIfNotNull<Boolean>("attachStacktrace") {
      options.isAttachStacktrace = it
    }
    data.getIfNotNull<Boolean>("enableAutoNativeBreadcrumbs") {
      options.isEnableActivityLifecycleBreadcrumbs = it
      options.isEnableAppLifecycleBreadcrumbs = it
      options.isEnableSystemEventBreadcrumbs = it
      options.isEnableAppComponentBreadcrumbs = it
      options.isEnableUserInteractionBreadcrumbs = it
    }
    data.getIfNotNull<Int>("maxBreadcrumbs") {
      options.maxBreadcrumbs = it
    }
    data.getIfNotNull<Int>("maxCacheItems") {
      options.maxCacheItems = it
    }
    data.getIfNotNull<String>("diagnosticLevel") {
      if (options.isDebug) {
        val sentryLevel = SentryLevel.valueOf(it.uppercase(Locale.ROOT))
        options.setDiagnosticLevel(sentryLevel)
      }
    }
    data.getIfNotNull<Boolean>("anrEnabled") {
      options.isAnrEnabled = it
    }
    data.getIfNotNull<Boolean>("sendDefaultPii") {
      options.isSendDefaultPii = it
    }
    data.getIfNotNull<Boolean>("enableNdkScopeSync") {
      options.isEnableScopeSync = it
    }
    data.getIfNotNull<String>("proguardUuid") {
      options.proguardUuid = it
    }

    val nativeCrashHandling = (data["enableNativeCrashHandling"] as? Boolean) ?: true
    // nativeCrashHandling has priority over anrEnabled
    if (!nativeCrashHandling) {
      options.isEnableUncaughtExceptionHandler = false
      options.isAnrEnabled = false
      // if split symbols are enabled, we need Ndk integration so we can't really offer the option
      // to turn it off
      // options.isEnableNdk = false
    }

    data.getIfNotNull<Boolean>("enableAutoPerformanceTracing") { enableAutoPerformanceTracing ->
      if (enableAutoPerformanceTracing) {
        autoPerformanceTracingEnabled = true
      }
    }

    data.getIfNotNull<Boolean>("sendClientReports") {
      options.isSendClientReports = it
    }

    data.getIfNotNull<Long>("maxAttachmentSize") {
      options.maxAttachmentSize = it
    }

    var sdkVersion = options.sdkVersion
    if (sdkVersion == null) {
      sdkVersion = SdkVersion(androidSdk, BuildConfig.VERSION_NAME)
    } else {
      sdkVersion.name = androidSdk
    }

    options.sdkVersion = sdkVersion
    options.sentryClientName = "$androidSdk/${BuildConfig.VERSION_NAME}"
    options.nativeSdkName = nativeSdk

    data.getIfNotNull<Int>("connectionTimeoutMillis") {
      options.connectionTimeoutMillis = it
    }
    data.getIfNotNull<Int>("readTimeoutMillis") {
      options.readTimeoutMillis = it
    }
    data.getIfNotNull<Map<String, Any>>("proxy") { proxyJson ->
      options.proxy =
        Proxy()
          .apply {
            host = proxyJson["host"] as? String
            port =
              (proxyJson["port"] as? Int)
                ?.let {
                  "$it"
                }
            (proxyJson["type"] as? String)
              ?.let {
                type =
                  try {
                    Type.valueOf(it.toUpperCase(Locale.ROOT))
                  } catch (_: IllegalArgumentException) {
                    Log.w("Sentry", "Could not parse `type` from proxy json: $proxyJson")
                    null
                  }
              }
            user = proxyJson["user"] as? String
            pass = proxyJson["pass"] as? String
          }
    }

    data.getIfNotNull<Map<String, Any>>("replay") {
      updateReplayOptions(options.experimental.sessionReplay, it)
    }
  }

  fun updateReplayOptions(
    options: SentryReplayOptions,
    data: Map<String, Any>,
  ) {
    options.sessionSampleRate = data["sessionSampleRate"] as? Double
    options.errorSampleRate = data["onErrorSampleRate"] as? Double
  }
}

// Call the `completion` closure if cast to map value with `key` and type `T` is successful.
@Suppress("UNCHECKED_CAST")
private fun <T> Map<String, Any>.getIfNotNull(
  key: String,
  callback: (T) -> Unit,
) {
  (get(key) as? T)?.let {
    callback(it)
  }
}
