import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';
import 'package:http/http.dart';

void main() {
  const org = 'sentry-sdks';
  const slug = 'sentry-flutter';
  const authToken = String.fromEnvironment('SENTRY_AUTH_TOKEN');
  const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Sentry.close();
  });

  // Using fake DSN for testing purposes.
  Future<void> setupSentryAndApp(WidgetTester tester, {String? dsn}) async {
    await setupSentry(() async {
      await tester.pumpWidget(SentryScreenshotWidget(
          child: DefaultAssetBundle(
        bundle: SentryAssetBundle(enableStructuredDataTracing: true),
        child: const MyApp(),
      )));
      await tester.pumpAndSettle();
    }, dsn ?? fakeDsn, isIntegrationTest: true);
  }

  // Tests

  testWidgets('setup sentry and render app', (tester) async {
    await setupSentryAndApp(tester);

    // Find any UI element and verify it is present.
    expect(find.text('Open another Scaffold'), findsOneWidget);
  });

  testWidgets('setup sentry and capture event', (tester) async {
    await setupSentryAndApp(tester);

    final event = SentryEvent();
    final sentryId = await Sentry.captureEvent(event);

    expect(sentryId != const SentryId.empty(), true);
  });

  testWidgets('setup sentry and capture exception', (tester) async {
    await setupSentryAndApp(tester);

    try {
      throw const SentryException(
          type: 'StarError', value: 'I have a bad feeling about this...');
    } catch (exception, stacktrace) {
      final sentryId =
          await Sentry.captureException(exception, stackTrace: stacktrace);

      expect(sentryId != const SentryId.empty(), true);
    }
  });

  testWidgets('setup sentry and capture message', (tester) async {
    await setupSentryAndApp(tester);

    final sentryId = await Sentry.captureMessage('hello world!');

    expect(sentryId != const SentryId.empty(), true);
  });

  testWidgets('setup sentry and capture user feedback', (tester) async {
    await setupSentryAndApp(tester);

    final feedback = SentryUserFeedback(
        eventId: SentryId.newId(),
        name: 'fixture-name',
        email: 'fixture@email.com',
        comments: 'fixture-comments');
    await Sentry.captureUserFeedback(feedback);
  });

  testWidgets('setup sentry and close', (tester) async {
    await setupSentryAndApp(tester);

    await Sentry.close();
  });

  testWidgets('setup sentry and add breadcrumb', (tester) async {
    await setupSentryAndApp(tester);

    final breadcrumb = Breadcrumb(message: 'fixture-message');
    await Sentry.addBreadcrumb(breadcrumb);
  });

  testWidgets('setup sentry and configure scope', (tester) async {
    await setupSentryAndApp(tester);

    await Sentry.configureScope((scope) async {
      await scope.setContexts('contexts-key', 'contexts-value');
      await scope.removeContexts('contexts-key');

      final user = SentryUser(id: 'fixture-id');
      await scope.setUser(user);
      await scope.setUser(null);

      final breadcrumb = Breadcrumb(message: 'fixture-message');
      await scope.addBreadcrumb(breadcrumb);
      await scope.clearBreadcrumbs();

      await scope.setExtra('extra-key', 'extra-value');
      await scope.removeExtra('extra-key');

      await scope.setTag('tag-key', 'tag-value');
      await scope.removeTag('tag-key');
    });
  });

  testWidgets('setup sentry and start transaction', (tester) async {
    await setupSentryAndApp(tester);

    final transaction = Sentry.startTransaction('transaction', 'test');
    await transaction.finish();
  });

  testWidgets('setup sentry and start transaction with context',
      (tester) async {
    await setupSentryAndApp(tester);

    final context = SentryTransactionContext('transaction', 'test');
    final transaction = Sentry.startTransactionWithContext(context);
    await transaction.finish();
  });

  group('e2e', () {
    var output = find.byKey(const Key('output'));
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('captureException', (tester) async {
      await setupSentryAndApp(tester, dsn: exampleDsn);

      await tester.tap(find.text('captureException'));
      await tester.pumpAndSettle();

      final text = output.evaluate().single.widget as Text;
      final id = text.data!;

      final uri = Uri.parse(
        'https://sentry.io/api/0/projects/$org/$slug/events/$id/',
      );

      final event = await fixture.poll(uri, authToken);
      expect(event, isNotNull);
      expect(fixture.validate(event!), isTrue);
    });
  });
}

class Fixture {
  Future<Map<String, dynamic>?> poll(Uri url, String authToken) async {
    final client = Client();

    const maxRetries = 10;
    const initialDelay = Duration(seconds: 2);
    const factor = 2;

    var retries = 0;
    var delay = initialDelay;

    while (retries < maxRetries) {
      try {
        final response = await client.get(
          url,
          headers: <String, String>{'Authorization': 'Bearer $authToken'},
        );
        if (response.statusCode == 200) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        }
      } catch (e) {
        // Do nothing
      } finally {
        retries++;
        await Future.delayed(delay);
        delay *= factor;
      }
    }
    return null;
  }

  bool validate(Map<String, dynamic> event) {
    final tags = event['tags'] as List<dynamic>;
    final dist = tags.firstWhere((element) => element['key'] == 'dist');
    if (dist['value'] != '1') {
      return false;
    }
    final environment =
        tags.firstWhere((element) => element['key'] == 'environment');
    if (environment['value'] != 'integration') {
      return false;
    }
    return true;
  }
}
