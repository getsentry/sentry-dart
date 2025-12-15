import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

/// Builds envelopes from buffered telemetry items.
@internal
abstract class EnvelopeBuilder<T extends TelemetryItem> {
  /// Builds one or more envelopes from the buffered items.
  ///
  /// Returns an empty list if items is empty.
  /// May return multiple envelopes (e.g., one per trace for spans).
  List<SentryEnvelope> build(List<BufferedItem<T>> items);
}
