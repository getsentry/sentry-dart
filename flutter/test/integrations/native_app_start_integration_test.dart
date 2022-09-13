@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  group('$NativeAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      fixture = Fixture();
    });

    test('native app start measurement added to first transaction', () async {
      fixture.options.autoAppStart = false;
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);

      fixture.getNativeAppStartIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched = await processor.apply(transaction) as SentryTransaction;

      final expected = SentryMeasurement('app_start_cold', 10);
      expect(enriched.measurements[0].name, expected.name);
      expect(enriched.measurements[0].value, expected.value);
    });

    test('native app start measurement not added to following transactions',
        () async {
      fixture.options.autoAppStart = false;
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);

      fixture.getNativeAppStartIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;

      var enriched = await processor.apply(transaction) as SentryTransaction;
      var secondEnriched = await processor.apply(enriched) as SentryTransaction;

      expect(secondEnriched.measurements.length, 1);
    });

    test('measurements appended', () async {
      fixture.options.autoAppStart = false;
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);
      final measurement = SentryMeasurement.warmAppStart(Duration(seconds: 1));

      fixture.getNativeAppStartIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer).copyWith();
      transaction.measurements.add(measurement);

      final processor = fixture.options.eventProcessors.first;

      var enriched = await processor.apply(transaction) as SentryTransaction;
      var secondEnriched = await processor.apply(enriched) as SentryTransaction;

      expect(secondEnriched.measurements.length, 2);
      expect(secondEnriched.measurements.contains(measurement), true);
    });

    test('native app start measurement not added if more than 60s', () async {
      fixture.options.autoAppStart = false;
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(60001);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);

      fixture.getNativeAppStartIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched = await processor.apply(transaction) as SentryTransaction;

      expect(enriched.measurements.isEmpty, true);
    });
  });
}

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final wrapper = MockNativeChannel();
  late final native = SentryNative();

  Fixture() {
    native.setNativeChannel(wrapper);
    native.reset();
  }

  NativeAppStartIntegration getNativeAppStartIntegration() {
    return NativeAppStartIntegration(
      native,
      () {
        return TestWidgetsFlutterBinding.ensureInitialized();
      },
    );
  }

  // ignore: invalid_use_of_internal_member
  SentryTracer createTracer({
    bool? sampled,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );
    return SentryTracer(context, MockHub());
  }
}
