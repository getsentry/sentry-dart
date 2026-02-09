@TestOn('vm')
library;
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_screenshot_widget_test.mocks.dart';
import 'test_widget.dart';

import '../mocks.mocks.dart' as mocks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onBuild', () {
    setUp(() {
      SentryScreenshotWidget.reset();
    });

    testWidgets('calls immediately if it has status already', (tester) async {
      await pumpTestElement(tester);
      final mock = MockCallbacks().onBuild;
      when(mock(any, any)).thenReturn(true);
      SentryScreenshotWidget.onBuild(mock);
      verify(mock(any, null));
    });

    testWidgets('calls after the widget appears', (tester) async {
      final mock = MockCallbacks().onBuild;
      when(mock(any, any)).thenReturn(true);
      SentryScreenshotWidget.onBuild(mock);

      await pumpTestElement(tester);

      final status = verify(mock(captureAny, null)).captured[0]
          as SentryScreenshotWidgetStatus?;
      expect(status, isNotNull);

      await pumpTestElement(tester);

      verify(mock(any, status));
    });

    testWidgets('unregisters the the callback if it returns false',
        (tester) async {
      bool returnValue = true;
      final mock = MockCallbacks().onBuild;
      when(mock(any, any)).thenAnswer((_) => returnValue);
      SentryScreenshotWidget.onBuild(mock);

      await pumpTestElement(tester);
      await pumpTestElement(tester);
      verify(mock(any, any)).called(2);

      returnValue = false;
      await pumpTestElement(tester);
      verify(mock(any, any)).called(1);
      await pumpTestElement(tester);
      verifyNever(mock(any, any));
    });
  });

  group('Screenshot Button', () {
    setUp(() {
      SentryScreenshotWidget.reset();
    });

    testWidgets('does not wrap child in Stack when button is not visible',
        (tester) async {
      var options = SentryFlutterOptions();
      var hub = mocks.MockHub();
      when(hub.options).thenReturn(options);

      await tester.pumpWidget(
        MaterialApp(
          home: SentryScreenshotWidget(
            hub: hub,
            child: const Text('fixture-child'),
          ),
        ),
      );

      // By default, the screenshot button is not visible, so no Stack should
      // be present in the SentryScreenshotWidget subtree.
      final screenshotWidgetElement =
          find.byType(SentryScreenshotWidget).evaluate().first;
      var foundStack = false;
      screenshotWidgetElement.visitChildElements((element) {
        if (element.widget is Stack) {
          foundStack = true;
        }
        element.visitChildElements((child) {
          if (child.widget is Stack) {
            foundStack = true;
          }
        });
      });
      expect(foundStack, isFalse);
    });

    testWidgets('shows & hides screenshot button', (tester) async {
      var options = SentryFlutterOptions();
      var hub = mocks.MockHub();
      when(hub.options).thenReturn(options);

      await tester.pumpWidget(
        MaterialApp(
          home: SentryScreenshotWidget(
            hub: hub,
            child: const Text('fixture-child'),
          ),
        ),
      );

      SentryScreenshotWidget.showTakeScreenshotButton();
      await tester.pumpAndSettle();

      expect(find.text('Take Screenshot'), findsOne);

      SentryScreenshotWidget.hideTakeScreenshotButton();
      await tester.pumpAndSettle();

      expect(find.text('Take Screenshot'), findsNothing);
    });

    testWidgets('presents feedback widget when screenshot is taken',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      var options = SentryFlutterOptions();
      options.navigatorKey = navigatorKey;

      var hub = mocks.MockHub();
      late var scope = Scope(options);

      when(hub.options).thenReturn(options);
      when(hub.configureScope(any)).thenAnswer((invocation) {
        final callback = invocation.positionalArguments.first;
        callback(scope);
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: SentryScreenshotWidget(
            hub: hub,
            child: const Text('fixture-child'),
          ),
        ),
      );

      SentryScreenshotWidget.showTakeScreenshotButton();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Screenshot'));
      await tester.pumpAndSettle();

      // Send button in feedback widget
      expect(find.text('Send Bug Report'), findsOne);
    });
  });

  group('SentryScreenshotWidgetStatus', () {
    group('matches', () {
      test('returns true for instances with very close pixelRatio values', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0000001, // Very close to 2.0
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isTrue);
      });

      test('returns true for instances with very close size dimensions', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100.0, 200.0),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100.005, 200.005),
          // Very close dimensions (within 0.01 tolerance)
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isTrue);
      });

      test(
          'returns false for instances with significantly different pixelRatio',
          () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.1, // Significantly different
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isFalse);
      });

      test(
          'returns false for instances with significantly different size dimensions',
          () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100.0, 200.0),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100.1, 200.0), // Significantly different width
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isFalse);
      });

      test(
          'returns true for instances with significantly different size dimensions',
          () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100.0, 200.0),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100.01, 200.0), // Significantly different width
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isTrue);
      });

      test('returns true if values are within tolerance', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100.0, 200.0),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100.005, 200.005),
          pixelRatio: 2.0000001,
          orientation: Orientation.portrait,
        );

        expect(status1.matches(status2), isTrue);
      });
    });
  });
}

@GenerateMocks([Callbacks])
abstract class Callbacks {
  bool onBuild(SentryScreenshotWidgetStatus a, SentryScreenshotWidgetStatus? b);
}
