import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'sentry_span_v2.dart';

@immutable
class SentrySpanSamplingContextV2 {
  final String name;
  final Map<String, SentryAttribute> attributes;

  SentrySpanSamplingContextV2(this.name, this.attributes);

  factory SentrySpanSamplingContextV2.fromSpan(SentrySpanV2 span) =>
      SentrySpanSamplingContextV2(
        span.name,
        Map.unmodifiable(span.attributes),
      );
}
