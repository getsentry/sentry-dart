import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('SentryMetric toJson', () {
    test('serializes all fields correctly', () {
      final traceId = SentryId.newId();
      final spanId = SpanId.newId();
      final timestamp = DateTime.utc(2024, 1, 15, 10, 30, 0);

      final metric = SentryCounterMetric(
        timestamp: timestamp,
        name: 'button_clicks',
        value: 5,
        traceId: traceId,
        spanId: spanId,
        unit: 'click',
        attributes: {'key': SentryAttribute.string('value')},
      );

      final json = metric.toJson();

      expect(json['timestamp'], 1705314600.0);
      expect(json['type'], 'counter');
      expect(json['name'], 'button_clicks');
      expect(json['value'], 5);
      expect(json['trace_id'], traceId.toString());
      expect(json['span_id'], spanId.toString());
      expect(json['unit'], 'click');
      expect(json['attributes']['key'], {'type': 'string', 'value': 'value'});
    });

    test('omits optional fields when null', () {
      final metric = SentryCounterMetric(
        timestamp: DateTime.utc(2024, 1, 15),
        name: 'test',
        value: 1,
        traceId: SentryId.newId(),
      );

      final json = metric.toJson();

      expect(json.containsKey('span_id'), isFalse);
      expect(json.containsKey('unit'), isFalse);
      expect(json.containsKey('attributes'), isFalse);
    });

    test('each metric type sets correct type field', () {
      final traceId = SentryId.newId();
      final timestamp = DateTime.utc(2024, 1, 15);

      expect(
        SentryCounterMetric(
                timestamp: timestamp, name: 't', value: 1, traceId: traceId)
            .toJson()['type'],
        'counter',
      );
      expect(
        SentryGaugeMetric(
                timestamp: timestamp, name: 't', value: 1, traceId: traceId)
            .toJson()['type'],
        'gauge',
      );
      expect(
        SentryDistributionMetric(
                timestamp: timestamp, name: 't', value: 1, traceId: traceId)
            .toJson()['type'],
        'distribution',
      );
    });
  });
}
