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

  Map<String, dynamic> get spanData => {
        if (url != null) 'url': url,
        if (query != null) 'http.query': query,
        if (fragment != null) 'http.fragment': fragment,
      };

  void applyToSpan(InstrumentationSpan? span) {
    if (span == null) {
      return;
    }
    spanData.forEach(span.setData);
  }
}
