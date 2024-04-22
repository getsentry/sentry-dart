import 'dart:async';
import 'dart:html';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/version.dart';

import 'event.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const dsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

Future<void> main() async {
  await Sentry.init(
    (options) => options
      ..dsn = dsn
      ..debug = true
      ..sendDefaultPii = true
      ..addEventProcessor(TagEventProcessor()),
    appRunner: runApp,
  );
}

Future<void> runApp() async {
  print('runApp');

  querySelector('#output')?.text = 'Your Dart app is running.';

  await Sentry.addBreadcrumb(
    Breadcrumb(
      message: 'Authenticated user',
      category: 'auth',
      type: 'debug',
      data: {
        'admin': true,
        'permissions': [1, 2, 3]
      },
    ),
  );

  await Sentry.configureScope((scope) async {
    scope
      // ..fingerprint = ['example-dart']
      ..transaction = '/example/app'
      ..level = SentryLevel.warning;
    await scope.setTag('build', '579');
    await scope.setExtra('company-name', 'Dart Inc');

    await scope.setUser(
      SentryUser(
        id: '800',
        username: 'first-user',
        email: 'first@user.lan',
        // ipAddress: '127.0.0.1',
        data: <String, String>{'first-sign-in': '2020-01-01'},
      ),
    );
  });

  querySelector('#btEvent')
      ?.onClick
      .listen((event) => captureCompleteExampleEvent());
  querySelector('#btMessage')?.onClick.listen((event) => captureMessage());
  querySelector('#btException')?.onClick.listen((event) => captureException());
  querySelector('#btUnhandledException')
      ?.onClick
      .listen((event) => captureUnhandledException());
}

Future<void> captureMessage() async {
  print('Capturing Message :  ');
  final sentryId = await Sentry.captureMessage(
    'Message 2',
    template: 'Message %s',
    params: ['2'],
  );
  print('capture message result : $sentryId');
  if (sentryId != SentryId.empty()) {
    querySelector('#messageResult')?.style.display = 'block';
  }
}

Future<void> captureException() async {
  try {
    await buildCard();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );

    print('Capture exception : SentryId: $sentryId');

    if (sentryId != SentryId.empty()) {
      querySelector('#exceptionResult')?.style.display = 'block';
    }
  }
}

Future<void> captureUnhandledException() async {
  querySelector('#unhandledResult')?.style.display = 'block';

  await buildCard();
}

Future<void> captureCompleteExampleEvent() async {
  print('\nReporting a complete event example: $sdkName');
  final sentryId = await Sentry.captureEvent(event);

  print('Response SentryId: $sentryId');

  if (sentryId != SentryId.empty()) {
    querySelector('#eventResult')?.style.display = 'block';
  }
}

Future<void> buildCard() async {
  await loadData();
}

Future<void> loadData() async {
  await parseData();
}

Future<void> parseData() async {
  throw StateError('This is a test error');
}

class TagEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return event..tags?.addAll({'page-locale': 'en-us'});
  }
}
