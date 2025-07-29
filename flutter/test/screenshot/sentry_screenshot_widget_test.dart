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
      when(hub.options).thenReturn(options);

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
    group('equality operator', () {
      test('returns true for identical instances', () {
        final status = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        expect(status == status, isTrue);
      });

      test('returns true for instances with same values', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        expect(status1 == status2, isTrue);
      });

      test('returns false for instances with different size', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(200, 300),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        expect(status1 == status2, isFalse);
      });

      test('returns false for instances with different pixelRatio', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 3.0,
          orientation: Orientation.portrait,
        );
        
        expect(status1 == status2, isFalse);
      });

      test('returns false for instances with different orientation', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.landscape,
        );
        
        expect(status1 == status2, isFalse);
      });

      test('returns false for null values comparison', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: null,
          pixelRatio: null,
          orientation: null,
        );
        
        expect(status1 == status2, isFalse);
      });

      test('returns true for instances with all null values', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: null,
          pixelRatio: null,
          orientation: null,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: null,
          pixelRatio: null,
          orientation: null,
        );
        
        expect(status1 == status2, isTrue);
      });

      test('returns false when compared to different type', () {
        final status = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        expect(status == 'not a status', isFalse);
        expect(status == 42, isFalse);
        expect(status == null, isFalse);
      });
    });

    group('hashCode', () {
      test('returns same hashCode for equal instances', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('returns different hashCode for different instances', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: const Size(200, 300),
          pixelRatio: 3.0,
          orientation: Orientation.landscape,
        );
        
        expect(status1.hashCode, isNot(equals(status2.hashCode)));
      });

      test('hashCode is consistent across multiple calls', () {
        final status = SentryScreenshotWidgetStatus(
          size: const Size(100, 200),
          pixelRatio: 2.0,
          orientation: Orientation.portrait,
        );
        
        final hashCode1 = status.hashCode;
        final hashCode2 = status.hashCode;
        
        expect(hashCode1, equals(hashCode2));
      });

      test('handles null values in hashCode calculation', () {
        final status1 = SentryScreenshotWidgetStatus(
          size: null,
          pixelRatio: null,
          orientation: null,
        );
        final status2 = SentryScreenshotWidgetStatus(
          size: null,
          pixelRatio: null,
          orientation: null,
        );
        
        expect(status1.hashCode, equals(status2.hashCode));
      });
    });
  });
}

@GenerateMocks([Callbacks])
abstract class Callbacks {
  bool onBuild(SentryScreenshotWidgetStatus a, SentryScreenshotWidgetStatus? b);
}
