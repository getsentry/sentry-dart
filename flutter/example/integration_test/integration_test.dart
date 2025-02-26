// ignore_for_file: avoid_print
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';

import 'utils.dart';

void main() {
  const org = 'sentry-sdks';
  const slug = 'sentry-flutter';
  const authToken = String.fromEnvironment('SENTRY_AUTH_TOKEN_E2E');
  const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  IntegrationTestWidgetsFlutterBinding.instance.framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  tearDown(() async {
    await Sentry.close();
  });

  // Using fake DSN for testing purposes.
  Future<void> setupSentryAndApp(WidgetTester tester,
      {String? dsn, BeforeSendCallback? beforeSendCallback}) async {
    await setupSentry(
      () async {
        await tester.pumpWidget(SentryScreenshotWidget(
            child: DefaultAssetBundle(
          bundle: SentryAssetBundle(enableStructuredDataTracing: true),
          child: const MyApp(),
        )));
      },
      dsn ?? fakeDsn,
      isIntegrationTest: true,
      beforeSendCallback: beforeSendCallback,
    );
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

  testWidgets('setup sentry and capture feedback', (tester) async {
    await setupSentryAndApp(tester);

    final associatedEventId = await Sentry.captureMessage('Associated');
    final feedback = SentryFeedback(
      message: 'message',
      contactEmail: 'john.appleseed@apple.com',
      name: 'John Appleseed',
      associatedEventId: associatedEventId,
    );
    await Sentry.captureFeedback(feedback);
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

      // ignore: deprecated_member_use
      await scope.setExtra('extra-key', 'extra-value');
      // ignore: deprecated_member_use
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

  testWidgets('setup sentry and test loading debug image', (tester) async {
    await restoreFlutterOnErrorAfter(() async {
      await setupSentryAndApp(tester);
    });

    // By default it should load all debug images
    final allDebugImages = await SentryFlutter.native
        ?.loadDebugImages(SentryStackTrace(frames: const []));
    // Typically loading all images results in a larger numbers
    expect(allDebugImages!.length > 100, isTrue);

    // We can take any other random image for testing
    final expectedImage = allDebugImages.first;
    expect(expectedImage.imageAddr, isNotNull);
    final imageAddr =
        int.parse(expectedImage.imageAddr!.replaceAll('0x', ''), radix: 16);

    // Use the base image address and increase by offset
    // so the instructionAddress will be within the range of the image address
    final imageOffset = (expectedImage.imageSize! / 2).toInt();
    final instructionAddr = '0x${(imageAddr + imageOffset).toRadixString(16)}';
    final sentryFrame = SentryStackFrame(instructionAddr: instructionAddr);

    final debugImageByStacktrace = await SentryFlutter.native
        ?.loadDebugImages(SentryStackTrace(frames: [sentryFrame]));
    expect(debugImageByStacktrace!.length, 1);
    expect(debugImageByStacktrace.first.imageAddr, isNotNull);
    expect(debugImageByStacktrace.first.imageAddr, isNotEmpty);
    expect(debugImageByStacktrace.first.imageAddr, expectedImage.imageAddr);
  });

  group('e2e', () {
    var output = find.byKey(const Key('output'));
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('captureException', (tester) async {
      late Uri uri;

      await restoreFlutterOnErrorAfter(() async {
        await setupSentryAndApp(tester,
            dsn: exampleDsn, beforeSendCallback: fixture.beforeSend);

        await tester.tap(find.text('captureException'));
        await tester.pumpAndSettle();

        final text = output.evaluate().single.widget as Text;
        final id = text.data!;

        uri = Uri.parse(
          'https://sentry.io/api/0/projects/$org/$slug/events/$id/',
        );
      });

      expect(authToken, isNotEmpty);

      final event = await fixture.poll(uri, authToken);
      expect(event, isNotNull);

      final sentEvents = fixture.sentEvents
          .where((el) => el!.eventId.toString() == event!['id']);
      expect(
          sentEvents.length, 1); // one button click should only send one error
      final sentEvent = sentEvents.first;

      final tags = event!['tags'] as List<dynamic>;

      print('event id: ${event['id']}');
      print('event title: ${event['title']}');
      expect(sentEvent!.eventId.toString(), event['id']);
      expect('_Exception: Exception: captureException', event['title']);
      expect(sentEvent.release, event['release']['version']);
      expect(
          2,
          (tags.firstWhere((e) => e['value'] == sentEvent.environment) as Map)
              .length);
      expect(sentEvent.fingerprint, event['fingerprint'] ?? []);
      expect(
          2,
          (tags.firstWhere((e) => e['value'] == SentryLevel.error.name) as Map)
              .length);
      expect(sentEvent.logger, event['logger']);

      final dist = tags.firstWhere((element) => element['key'] == 'dist');
      expect('1', dist['value']);

      final environment =
          tags.firstWhere((element) => element['key'] == 'environment');
      expect('integration', environment['value']);
    });
  });
}

class Fixture {
  List<SentryEvent?> sentEvents = [];

  FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
    sentEvents.add(event);
    return event;
  }

  Future<Map<String, dynamic>?> poll(Uri url, String authToken) async {
    final client = Client();

    const maxRetries = 10;
    const initialDelay = Duration(seconds: 2);
    const delayIncrease = Duration(seconds: 2);

    var retries = 0;
    var delay = initialDelay;

    while (retries < maxRetries) {
      try {
        print('Trying to fetch $url [try $retries/$maxRetries]');
        final response = await client.get(
          url,
          headers: <String, String>{'Authorization': 'Bearer $authToken'},
        );
        print('Response status code: ${response.statusCode}');
        if (response.statusCode == 200) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } else if (response.statusCode == 401) {
          print('Cannot fetch $url - invalid auth token.');
          break;
        }
      } catch (e) {
        // Do nothing
      } finally {
        retries++;
        await Future.delayed(delay);
        delay += delayIncrease;
      }
    }
    return null;
  }
}
