import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

@internal
abstract class EnvelopeBuilder<T extends TelemetryItem> {
  /// May return multiple envelopes (e.g., one per segment for spans).
  List<SentryEnvelope> build(List<EncodedTelemetryItem<T>> items);
}
