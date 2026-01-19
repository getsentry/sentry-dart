import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'sentry_span_v2.dart';

@internal
extension SpanAttributeUtils on SentrySpanV2 {
  void addAttributesIfAbsent(Map<String, SentryAttribute> attributes) {
    if (attributes.isEmpty) {
      return;
    }

    final existing = this.attributes;
    for (final entry in attributes.entries) {
      if (!existing.containsKey(entry.key)) {
        setAttribute(entry.key, entry.value);
      }
    }
  }
}
