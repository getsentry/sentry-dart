import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/mobile_vitals_integration.dart';
import 'package:sentry_flutter/src/sentry_native_state.dart';
import 'package:sentry_flutter/src/sentry_native_wrapper.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:flutter/scheduler.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  group('$MobileVitalsIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('native app start measurement added to first transaction', () async {
      fixture.options.autoAppStart = false;
      fixture.state.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);

      fixture.getMobileVitalsIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched = await processor.apply(transaction) as SentryTransaction;

      final expected = SentryMeasurement('app_start_cold', 10);
      expect(enriched.measurements?[0].name, expected.name);
      expect(enriched.measurements?[0].value, expected.value);
    });

    test('native app start measurement not added to following transactions',
        () async {
      fixture.options.autoAppStart = false;
      fixture.state.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.wrapper.nativeAppStart = NativeAppStart(0, true);

      fixture.getMobileVitalsIntegration().call(MockHub(), fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;

      var enriched = await processor.apply(transaction) as SentryTransaction;
      var secondEnriched = await processor.apply(enriched) as SentryTransaction;

      expect(secondEnriched.measurements?.length, 1);
    });
  });
}

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final wrapper = MockNativeWrapper();
  final state = SentryNative();

  MobileVitalsIntegration getMobileVitalsIntegration() {
    return MobileVitalsIntegration(
      wrapper,
      state,
      () {
        return SchedulerBinding.instance;
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
