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
    if (url != null) SemanticAttributesConstants.urlFull: url,
    if (query != null) SemanticAttributesConstants.httpQuery: query,
    if (fragment != null) SemanticAttributesConstants.httpFragment: fragment,
  };

  void applyToSpan(InstrumentationSpan? span) {
    if (span == null) {
      return;
    }
    spanData.forEach(span.setData);
  }
}
