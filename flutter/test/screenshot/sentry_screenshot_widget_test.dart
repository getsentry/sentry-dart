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
}

@GenerateMocks([Callbacks])
abstract class Callbacks {
  bool onBuild(SentryScreenshotWidgetStatus a, SentryScreenshotWidgetStatus? b);
}
