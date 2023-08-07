package io.sentry.flutter

import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions

class SentryFlutter(
  private val options: SentryAndroidOptions
) {
  fun initNativeSdk(data: Map<String, Any>) {
    data.getIfNotNull<String>("dsn") {
      options.dsn = it
    }
  }
}

// Call the `completion` closure if cast to map value with `key` and type `T` is successful.
@Suppress("UNCHECKED_CAST")
private fun <T> Map<String, Any>.getIfNotNull(key: String, callback: (T) -> Unit) {
  (get(key) as? T)?.let {
    callback(it)
  }
}
