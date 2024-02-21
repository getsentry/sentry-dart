@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import '../navigation/fake_app_start_tracker.dart';

void main() {
  group('$NativeAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      fixture = Fixture();
    });

    test('native app start measurement added to first transaction', () async {
      fixture.options.autoAppStart = false;
      fixture.appStartTracker.setAppStartInfo(
        AppStartInfo(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10),
          SentryMeasurement('app_start_cold', 10,
              unit: DurationSentryMeasurementUnit.milliSecond),
        ),
      );

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched = await processor.apply(transaction) as SentryTransaction;

      final measurement = enriched.measurements['app_start_cold']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('native app start measurement not added to following transactions',
        () async {
      fixture.options.autoAppStart = false;
      fixture.appStartTracker.setAppStartInfo(
        AppStartInfo(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10),
          SentryMeasurement('app_start_cold', 10,
              unit: DurationSentryMeasurementUnit.milliSecond),
        ),
      );

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;

      var enriched = await processor.apply(transaction) as SentryTransaction;
      var secondEnriched = await processor.apply(enriched) as SentryTransaction;

      expect(secondEnriched.measurements.length, 1);
    });

    test('measurements appended', () async {
      fixture.options.autoAppStart = false;
      fixture.appStartTracker.setAppStartInfo(
        AppStartInfo(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10),
          SentryMeasurement('app_start_cold', 10,
              unit: DurationSentryMeasurementUnit.milliSecond),
        ),
      );
      final measurement = SentryMeasurement.warmAppStart(Duration(seconds: 1));

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer).copyWith();
      transaction.measurements[measurement.name] = measurement;

      final processor = fixture.options.eventProcessors.first;

      var enriched = await processor.apply(transaction) as SentryTransaction;
      var secondEnriched = await processor.apply(enriched) as SentryTransaction;

      expect(secondEnriched.measurements.length, 2);
      expect(secondEnriched.measurements.containsKey(measurement.name), true);
    });

    test('native app start measurement not added if more than 60s', () async {
      fixture.options.autoAppStart = false;
      fixture.appStartTracker.setAppStartInfo(
        AppStartInfo(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(60001),
          SentryMeasurement('app_start_cold', 60001,
              unit: DurationSentryMeasurementUnit.milliSecond),
        ),
      );

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched = await processor.apply(transaction) as SentryTransaction;

      expect(enriched.measurements.isEmpty, true);
    });

    test(
        'native app start measurement only added once for multiple different transactions',
        () async {
      fixture.options.autoAppStart = false;
      await fixture.native.fetchNativeAppStart();
      fixture.appStartTracker.setAppStartInfo(
        AppStartInfo(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(10),
          SentryMeasurement('app_start_cold', 10,
              unit: DurationSentryMeasurementUnit.milliSecond),
        ),
      );

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final processor = fixture.options.eventProcessors.first;
      final tracer = fixture.createTracer();

      // Represents the app start transaction
      final transaction = SentryTransaction(tracer);
      var enriched = await processor.apply(transaction) as SentryTransaction;
      expect(enriched.measurements.length, 1);

      // Represents any other transaction that happened afterwards
      final transaction2 = SentryTransaction(tracer);
      var secondEnriched =
          await processor.apply(transaction2) as SentryTransaction;
      expect(secondEnriched.measurements.length, 0);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final binding = MockNativeChannel();
  final appStartTracker = FakeAppStartTracker();
  late final native = SentryNative(options, binding);

  Fixture() {
    native.reset();
    when(hub.options).thenReturn(options);
  }

  NativeAppStartIntegration getNativeAppStartIntegration() {
    return NativeAppStartIntegration(
      native,
      () {
        return TestWidgetsFlutterBinding.ensureInitialized();
      },
      appStartTracker: appStartTracker,
    );
  }

  // ignore: invalid_use_of_internal_member
  SentryTracer createTracer({
    bool? sampled = true,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
    );
    return SentryTracer(context, hub);
  }
}
