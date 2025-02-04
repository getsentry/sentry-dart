import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  group('SentryWidget', () {
    const testChild = Text('Test Child');

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('SentryWidget wraps child with SentryUserInteractionWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SentryWidget(child: testChild),
        ),
      );

      expect(find.byType(SentryUserInteractionWidget), findsOneWidget);
      expect(find.byWidget(testChild), findsOneWidget);
    });

    testWidgets('SentryWidget wraps child with SentryScreenshotWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SentryWidget(child: testChild),
        ),
      );

      expect(find.byType(SentryScreenshotWidget), findsOneWidget);
      expect(find.byWidget(testChild), findsOneWidget);
    });

    testWidgets(
        'SentryWidget does not add SentryUserInteractionWidget or SentryScreenshotWidget when multiview-app',
        (WidgetTester tester) async {
      final options = defaultTestOptions();
      options.isMultiViewApp = true;
      final hub = MockHub();
      when(hub.options).thenReturn(options);

      await tester.pumpWidget(
        MaterialApp(
          home: SentryWidget(
            hub: hub,
            child: testChild,
          ),
        ),
      );

      expect(find.byType(SentryUserInteractionWidget), findsNothing);
      expect(find.byType(SentryScreenshotWidget), findsNothing);
      expect(find.byWidget(testChild), findsOneWidget);
    });
  });
}
