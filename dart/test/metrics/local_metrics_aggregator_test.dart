import 'package:sentry/src/metrics/local_metrics_aggregator.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../mocks.dart';

void main() {
  group('add', () {
    late LocalMetricsAggregator aggregator;

    setUp(() {
      aggregator = LocalMetricsAggregator();
    });

    test('same metric multiple times aggregates them', () async {
      aggregator.add(fakeMetric, 1);
      aggregator.add(fakeMetric, 2);
      final summaries = aggregator.getSummaries();
      expect(summaries.length, 1);
      final summary = summaries.values.first;
      expect(summary.length, 1);
    });

    test('same metric different tags aggregates summary bucket', () async {
      aggregator.add(fakeMetric, 1);
      aggregator.add(fakeMetric..tags.clear(), 2);
      final summaries = aggregator.getSummaries();
      expect(summaries.length, 1);
      final summary = summaries.values.first;
      expect(summary.length, 2);
    });

    test('different metrics does not aggregate them', () async {
      aggregator.add(fakeMetric, 1);
      aggregator.add(fakeMetric2, 2);
      final summaries = aggregator.getSummaries();
      expect(summaries.length, 2);
    });
  });
}
