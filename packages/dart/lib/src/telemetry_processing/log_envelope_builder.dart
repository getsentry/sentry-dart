import '../../sentry.dart';

import 'envelope_builder.dart';
import 'telemetry_buffer.dart';

/// Single envelope for all logs, no grouping compared to [SpanEnvelopeBuilder].
class LogEnvelopeBuilder implements EnvelopeBuilder<SentryLog> {
  final SentryOptions _options;

  LogEnvelopeBuilder(this._options);

  @override
  List<SentryEnvelope> build(List<BufferedItem<SentryLog>> items) {
    if (items.isEmpty) return [];

    final encoded = items.map((i) => i.encoded).toList();
    final envelope = SentryEnvelope.fromLogsData(encoded, _options.sdk);
    return [envelope];
  }
}
