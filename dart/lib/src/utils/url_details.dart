import 'package:meta/meta.dart';
import '../../sentry.dart';

/// Sanitized url data for sentry.io
@internal
class UrlDetails {
  UrlDetails({this.url, this.query, this.fragment});

  final String? url;
  final String? query;
  final String? fragment;

  late final urlOrFallback = url ?? 'unknown';

  void applyToSpan(ISentrySpan? span) {
    if (span == null) {
      return;
    }
    if (url != null) {
      span.setData('url', url);
    }
    if (query != null) {
      span.setData("http.query", query);
    }
    if (fragment != null) {
      span.setData("http.fragment", fragment);
    }
  }
}
