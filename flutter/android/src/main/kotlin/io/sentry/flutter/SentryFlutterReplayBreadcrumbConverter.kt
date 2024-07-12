package io.sentry.flutter

import io.sentry.Breadcrumb
import io.sentry.android.replay.DefaultReplayBreadcrumbConverter
import io.sentry.rrweb.RRWebBreadcrumbEvent
import io.sentry.rrweb.RRWebEvent
import io.sentry.rrweb.RRWebSpanEvent
import kotlin.LazyThreadSafetyMode.NONE

class SentryFlutterReplayBreadcrumbConverter : DefaultReplayBreadcrumbConverter() {
  internal companion object {
    private val snakecasePattern by lazy(NONE) { "_[a-z]".toRegex() }
    private val supportedNetworkData =
      setOf(
        "status_code",
        "method",
        "response_body_size",
        "request_body_size",
      )
  }

  override fun convert(breadcrumb: Breadcrumb): RRWebEvent? {
    return when (breadcrumb.category) {
      null -> null
      "sentry.event" -> null
      "sentry.transaction" -> null
      "http" -> convertNetworkBreadcrumb(breadcrumb)
      "navigation" -> newRRWebBreadcrumb(breadcrumb)
      "ui.click" ->
        newRRWebBreadcrumb(breadcrumb).apply {
          category = "ui.tap"
          message = getTouchPathMessage(breadcrumb.data)
        }

      else -> {
        val nativeBreadcrumb = super.convert(breadcrumb)

        // ignore native navigation breadcrumbs
        if (nativeBreadcrumb is RRWebBreadcrumbEvent) {
          if (nativeBreadcrumb.category == "navigation") {
            return null
          }
        }

        nativeBreadcrumb
      }
    }
  }

  private fun newRRWebBreadcrumb(breadcrumb: Breadcrumb): RRWebBreadcrumbEvent =
    RRWebBreadcrumbEvent().apply {
      category = breadcrumb.category
      level = breadcrumb.level
      data = breadcrumb.data
      timestamp = breadcrumb.timestamp.time
      breadcrumbTimestamp = breadcrumb.timestamp.time / 1000.0
      breadcrumbType = "default"
    }

  private fun getTouchPathMessage(data: Map<String, Any?>): String {
    var message = data["view.id"] as String? ?: ""
    if (data.containsKey("label")) {
      message =
        if (message.isNotEmpty()) {
          "$message, label: ${data["label"]}"
        } else {
          data["label"] as String
        }
    }

    if (data.containsKey("view.class")) {
      message = "${data["view.class"]}($message)"
    }

    return message
  }

  private fun convertNetworkBreadcrumb(breadcrumb: Breadcrumb): RRWebEvent? {
    var rrWebEvent = super.convert(breadcrumb)
    if (rrWebEvent == null &&
      breadcrumb.data.containsKey("start_timestamp") &&
      breadcrumb.data.containsKey("end_timestamp")
    ) {
      rrWebEvent =
        RRWebSpanEvent().apply {
          op = "resource.http"
          timestamp = breadcrumb.timestamp.time
          description = breadcrumb.data["url"] as String
          startTimestamp = (breadcrumb.data["start_timestamp"] as Long) / 1000.0
          endTimestamp = (breadcrumb.data["end_timestamp"] as Long) / 1000.0
          data =
            breadcrumb.data
              .filterKeys { key -> supportedNetworkData.contains(key) }
              .mapKeys { (key, _) -> key.snakeToCamelCase() }
        }
    }
    return rrWebEvent
  }

  private fun String.snakeToCamelCase(): String = replace(snakecasePattern) { it.value.last().uppercase() }
}
