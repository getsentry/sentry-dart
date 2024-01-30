import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  });
}
