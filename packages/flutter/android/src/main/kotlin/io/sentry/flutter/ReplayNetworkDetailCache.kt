package io.sentry.flutter

/**
 * Short-lived, size-bounded store for Session Replay's captured HTTP request/response detail,
 * correlated by the `replay_request_id` the Dart side stamps onto the matching `http`
 * breadcrumb. Deliberately never touches native `Scope`: entries here are only ever read by
 * [SentryFlutterReplayBreadcrumbConverter] while building a replay recording, so this data can
 * never end up attached to a crash event.
 */
class ReplayNetworkDetailCache(private val maxEntries: Int = 100) {
  private val entries =
    object : LinkedHashMap<String, Pair<Map<String, Any?>?, Map<String, Any?>?>>(
      16,
      0.75f,
      false,
    ) {
      override fun removeEldestEntry(
        eldest: MutableMap.MutableEntry<String, Pair<Map<String, Any?>?, Map<String, Any?>?>>,
      ): Boolean = size > maxEntries
    }

  @Synchronized
  fun put(id: String, request: Map<String, Any?>?, response: Map<String, Any?>?) {
    entries[id] = request to response
  }

  /** Returns and removes the entry for [id], so a given id's detail is only used once. */
  @Synchronized
  fun consume(id: String): Pair<Map<String, Any?>?, Map<String, Any?>?>? = entries.remove(id)
}
