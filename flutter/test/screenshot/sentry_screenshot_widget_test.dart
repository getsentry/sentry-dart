@TestOn('vm')
library flutter_test;
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    '$SentryScreenshotWidget does not apply when attachScreenshot is false',
    (tester) async {
      await tester.pumpWidget(
        fixture.getSut(
          attachScreenshot: false,
        ),
      );

      final widget = find.byType(MyApp);
      final repaintBoundaryFinder = find.descendant(
        of: widget,
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaryFinder, findsNothing);
    },
  );

  testWidgets(
    '$SentryScreenshotWidget applies when attachScreenshot is true',
    (tester) async {
      await tester.pumpWidget(
        fixture.getSut(
          attachScreenshot: true,
        ),
      );

      final widget = find.byType(MyApp);
      final repaintBoundaryFinder = find.ancestor(
        of: widget,
        matching: find.byKey(sentryScreenshotWidgetGlobalKey),
      );
      expect(repaintBoundaryFinder, findsOneWidget);
    },
  );
}

class Fixture {
  final _options = SentryFlutterOptions(dsn: fakeDsn);
  late Hub hub;

  SentryScreenshotWidget getSut({
    bool attachScreenshot = false,
  }) {
    _options.attachScreenshot = attachScreenshot;

    hub = Hub(_options);

    return SentryScreenshotWidget(
      hub: hub,
      child: MaterialApp(home: MyApp()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('test');
  }
}
