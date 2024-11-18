import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentryTransaction _transaction;

  setUp(() async {
    await SentryFlutter.init((options) {
      // ignore: invalid_use_of_internal_member
      options.automatedTestMode = true;
      options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
      options.debug = true;
      options.tracesSampleRate = 1.0;

      options.beforeSendTransaction = (transaction) {
        _transaction = transaction;
        return transaction;
      };
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  testWidgets('app start measurements are processed and reported',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test Widget'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_transaction.measurements, isNotEmpty);
    expect(_transaction.measurements['time_to_initial_display'], isNotNull);
    expect(_transaction.measurements['app_start_cold'], isNotNull);
  });
}
