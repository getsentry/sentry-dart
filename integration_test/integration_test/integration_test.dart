import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:integration_test_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Sentry.close();
  });

  Future<void> setupSentryAndApp(WidgetTester tester, {String? dsn}) async {
    final onError = FlutterError.onError;
    String authToken = const String.fromEnvironment('SENTRY_AUTH_TOKEN');
    await setupSentry(() async {
      await tester.pumpWidget(const IntegrationTestApp());
      await tester.pumpAndSettle();
    }, dsn: dsn ?? 'https://abc@def.ingest.sentry.io/1234567', authToken: authToken);
    FlutterError.onError = onError;
  }

  // Tests

  testWidgets('send exception end to end', (tester) async {
    await setupSentryAndApp(
      tester,
      dsn: 'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562'
    );

    await tester.tap(find.text('Sentry Exception E2E'));
    await tester.pumpAndSettle();

    // Find any UI element and verify it is present.
    expect(find.text('Sentry Exception E2E: Success'), findsOneWidget);
  });
}
