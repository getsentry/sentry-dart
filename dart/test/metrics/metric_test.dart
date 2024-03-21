import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Encode to statsd', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encode CounterMetric', () async {
      final int bucketKey = 10;
      final String expectedStatsd =
          'key_metric_@hour:2.0|c|#tag1:tag value 1,key_2:@13/-d_s|T10';
      final String actualStatsd =
          fixture.counterMetric.encodeToStatsd(bucketKey);
      expect(actualStatsd, expectedStatsd);
    });
  });

  group('getCompositeKey', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('getCompositeKey escapes commas from tags', () async {
      final Iterable<String> tags = fixture.counterMetric.tags.values;
      final String joinedTags = tags.join();
      final Iterable<String> expectedTags =
          tags.map((e) => e.replaceAll(',', '\\,'));
      final String actualKey = fixture.counterMetric.getCompositeKey();

      expect(joinedTags.contains(','), true);
      expect(joinedTags.contains('\\,'), false);
      expect(actualKey.contains('\\,'), true);
      for (var tag in expectedTags) {
        expect(actualKey.contains(tag), true);
      }
    });

    test('getCompositeKey CounterMetric', () async {
      final String expectedKey =
          'c_key metric!_hour_tag1=tag\\, value 1,key 2=&@"13/-d_s';
      final String actualKey = fixture.counterMetric.getCompositeKey();
      expect(actualKey, expectedKey);
    });
  });
}

class Fixture {
  final CounterMetric counterMetric = CounterMetric(
    value: 2,
    key: 'key metric!',
    unit: DurationSentryMeasurementUnit.hour,
    tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
  );
}
