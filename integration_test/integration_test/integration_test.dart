import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:integration_test_app/main.dart';

void main() {
  const org = 'sentry-sdks';
  const slug = 'sentry-flutter';
  const authToken = String.fromEnvironment('SENTRY_AUTH_TOKEN');

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Sentry.close();
  });

  Future<void> setupSentryAndApp(WidgetTester tester, {String? dsn}) async {
    final onError = FlutterError.onError;
    await setupSentry(() async {
      await tester.pumpWidget(const IntegrationTestApp());
      await tester.pumpAndSettle();
    }, dsn: dsn ?? 'https://abc@def.ingest.sentry.io/1234567');
    FlutterError.onError = onError;
  }

  // Tests

  group('e2e', () {
    var output = find.byKey(const Key('output'));
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('captureException', (tester) async {
      await setupSentryAndApp(
          tester,
          dsn: 'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562'
      );

      await tester.tap(find.text('captureException'));
      await tester.pumpAndSettle();

      final text = output
          .evaluate()
          .single
          .widget as Text;
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
