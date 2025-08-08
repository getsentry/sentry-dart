// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../mocks.dart';
import 'package:sentry_flutter/src/display/display_txn.dart';

void main() {
  testWidgets('didPush starts route and schedules TTID end on first frame',
      (tester) async {
    final options = SentryFlutterOptions(dsn: fakeDsn)
      ..experimentalUseDisplayTimingV2 = true
      ..tracesSampleRate = 1.0;
    final hub = Hub(options);

    final observer = SentryNavigatorObserverV2(hub: hub);

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: const SizedBox.shrink(),
      routes: {
        '/second': (_) => const SizedBox.shrink(),
      },
    ));

    // Push a named route
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/second');

    // First pump builds the frame, post-frame will be executed after
    await tester.pump();

    // After first frame completion, TTID should be ended.
    // The engine also starts a timeout timer; clear it to avoid test pending timers.
    final snap = (hub.options as SentryFlutterOptions).displayTiming.snapshot();
    expect(snap.route, isA<Active>());
    final active = snap.route as Active;
    expect(active.ttidOpen, isFalse);

    // Abort current to cancel the engine's timeout timer and avoid pending timer failures
    (hub.options as SentryFlutterOptions)
        .displayTiming
        .abortCurrent(slot: DisplaySlot.route, when: hub.options.clock());
  });
}
