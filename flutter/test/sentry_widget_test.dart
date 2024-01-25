import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';
import 'user_interaction/sentry_user_interaction_widget_test.dart';

void main() {
  group('SentryWidget', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('attaches screenshot widget when enabled', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(fixture.getSut());

        expect(find.byType(SentryScreenshotWidget), findsOneWidget);
      });
    });

    testWidgets('does not attach screenshot widget when disabled',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(fixture.getSut(attachScreenshot: false));

        expect(find.byType(SentryScreenshotWidget), findsNothing);
      });
    });

    testWidgets(
        'attaches user interaction widget when enableUserInteractionTracing is enabled',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(fixture.getSut(
            enableUserInteractionTracing: true,
            enableUserInteractionBreadcrumbs: false));

        expect(find.byType(SentryUserInteractionWidget), findsOneWidget);
      });
    });

    testWidgets(
        'attaches user interaction widget when enableUserInteractionBreadcrumbs is enabled',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(fixture.getSut(
            enableUserInteractionTracing: false,
            enableUserInteractionBreadcrumbs: true));

        expect(find.byType(SentryUserInteractionWidget), findsOneWidget);
      });
    });

    testWidgets('does not attach user interaction widget when disabled',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(fixture.getSut(
            enableUserInteractionTracing: false,
            enableUserInteractionBreadcrumbs: false));

        expect(find.byType(SentryUserInteractionWidget), findsNothing);
      });
    });
  });

  group('SentryWidget', () {
    test('test options are true in SentryFlutter.init', () async {
      await SentryFlutter.init((p0) => {
            p0.dsn = fakeDsn,
            p0.attachScreenshot = true,
            p0.enableUserInteractionTracing = true,
            p0.enableUserInteractionBreadcrumbs = true,
          });

      expect(SentryFlutter.flutterOptions.attachScreenshot, true);
      expect(SentryFlutter.flutterOptions.enableUserInteractionTracing, true);
      expect(SentryFlutter.flutterOptions.enableUserInteractionBreadcrumbs, true);
    });

    test('test options are false in SentryFlutter.init', () async {
      await SentryFlutter.init((p0) => {
        p0.dsn = fakeDsn,
        p0.attachScreenshot = false,
        p0.enableUserInteractionTracing = false,
        p0.enableUserInteractionBreadcrumbs = false,
      });

      expect(SentryFlutter.flutterOptions.attachScreenshot, false);
      expect(SentryFlutter.flutterOptions.enableUserInteractionTracing, false);
      expect(SentryFlutter.flutterOptions.enableUserInteractionBreadcrumbs, false);
    });
  });
}

class Fixture {
  // SentryWidget uses an internal static flutterOptions reference to get the options
  final _options = SentryFlutter.flutterOptions;
  final _transport = MockTransport();
  late Hub hub;

  SentryWidget getSut({
    bool enableUserInteractionTracing = true,
    bool enableUserInteractionBreadcrumbs = true,
    bool attachScreenshot = true,
  }) {
    _options.dsn = fakeDsn;
    _options.transport = _transport;
    _options.attachScreenshot = attachScreenshot;
    _options.enableUserInteractionTracing = enableUserInteractionTracing;
    _options.enableUserInteractionBreadcrumbs =
        enableUserInteractionBreadcrumbs;

    hub = Hub(_options);

    return SentryWidget(
      child: MyApp(),
    );
  }
}
