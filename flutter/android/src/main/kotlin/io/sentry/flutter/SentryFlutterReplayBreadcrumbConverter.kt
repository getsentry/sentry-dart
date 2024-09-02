package io.sentry.flutter

import io.sentry.Breadcrumb
import io.sentry.android.replay.DefaultReplayBreadcrumbConverter
import io.sentry.rrweb.RRWebBreadcrumbEvent
import io.sentry.rrweb.RRWebEvent
import io.sentry.rrweb.RRWebSpanEvent
import java.util.Date

private const val MILLIS_PER_SECOND = 1000.0

class SentryFlutterReplayBreadcrumbConverter : DefaultReplayBreadcrumbConverter() {
  internal companion object {
    private val supportedNetworkData =
      mapOf(
        "status_code" to "statusCode",
        "method" to "method",
        "response_body_size" to "responseBodySize",
        "request_body_size" to "requestBodySize",
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
          message = breadcrumb.data["path"] as String?
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
      breadcrumbTimestamp = doubleTimestamp(breadcrumb.timestamp)
      breadcrumbType = "default"
    }

  private fun doubleTimestamp(date: Date) = doubleTimestamp(date.time)

  private fun doubleTimestamp(timestamp: Long) = timestamp / MILLIS_PER_SECOND

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
          startTimestamp = doubleTimestamp(breadcrumb.data["start_timestamp"] as Long)
          endTimestamp = doubleTimestamp(breadcrumb.data["end_timestamp"] as Long)
          data =
            breadcrumb.data
              .filterKeys { key -> supportedNetworkData.containsKey(key) }
              .mapKeys { (key, _) -> supportedNetworkData[key] }
        }
    }
    return rrWebEvent
  }
}
