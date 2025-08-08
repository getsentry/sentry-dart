// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/generic_app_start_integration_v2.dart';
import 'package:sentry_flutter/src/display/display_txn.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

void main() {
  group('GenericAppStartIntegrationV2', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds sdk integration when tracing and flag enabled', () async {
      final sut = fixture.getSut();
      fixture.options.tracesSampleRate = 1.0;
      fixture.options.experimentalUseDisplayTimingV2 = true;

      sut.call(fixture.hub, fixture.options);
      expect(
        fixture.options.sdk.integrations,
        contains('GenericAppStartV2'),
      );
    });

    test('ends TTID on first frame via controller', () async {
      final sut = fixture.getSut();
      fixture.options.tracesSampleRate = 1.0;
      fixture.options.experimentalUseDisplayTimingV2 = true;
      fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

      sut.call(fixture.hub, fixture.options);

      // allow post-frame callback to run
      await Future<void>.delayed(Duration(milliseconds: 1));

      final snap = fixture.options.displayTiming.snapshot();
      expect(snap.root, isA<Active>());
      final active = snap.root as Active;
      expect(active.ttidOpen, isFalse);

      // avoid pending timers
      fixture.options.displayTiming
          .abortCurrent(slot: DisplaySlot.root, when: fixture.options.clock());
    });
  });
}

class Fixture {
  Fixture() {
    options = defaultTestOptions();
    hub = Hub(options);
  }

  late final SentryFlutterOptions options;
  late final Hub hub;
  final fakeFrameHandler = FakeFrameCallbackHandler();

  GenericAppStartIntegrationV2 getSut() {
    return GenericAppStartIntegrationV2(fakeFrameHandler);
  }
}
