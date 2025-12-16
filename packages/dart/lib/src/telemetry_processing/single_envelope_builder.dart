import '../../sentry.dart';
import 'envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_item.dart';

/// All items in a single envelope.
class SingleEnvelopeBuilder<T extends TelemetryItem>
    implements EnvelopeBuilder<T> {
  final SentryEnvelope Function(List<EncodedTelemetryItem<T>> items) _create;

  SingleEnvelopeBuilder(this._create);

  @override
  List<SentryEnvelope> build(List<EncodedTelemetryItem<T>> items) =>
      items.isEmpty ? [] : [_create(items)];
}

class LogEnvelopeBuilder extends SingleEnvelopeBuilder<SentryLog> {
  LogEnvelopeBuilder(SentryOptions options)
      : super((items) => SentryEnvelope.fromLogsData(
              items.map((i) => i.encoded).toList(),
              options.sdk,
            ));
}
