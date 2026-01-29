import 'package:meta/meta.dart';
import '../../sentry.dart';

/// Sanitized url data for sentry.io
@internal
class UrlDetails {
  UrlDetails({this.url, this.query, this.fragment});

  final String? url;
  final String? query;
  final String? fragment;

  static const _unknown = 'unknown';

  late final urlOrFallback =
      Uri.tryParse(url ?? _unknown)?.toString() ?? _unknown;

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

  void applyToInstrumentationSpan(InstrumentationSpan? span) {
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
