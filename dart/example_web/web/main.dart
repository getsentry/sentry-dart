import 'dart:async';
import 'package:web/web.dart';

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

  document.querySelector('#output')?.text = 'Your Dart app is running.';

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
    // ignore: deprecated_member_use
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

  document
      .querySelector('#btEvent')
      ?.onClick
      .listen((event) => captureCompleteExampleEvent());
  document
      .querySelector('#btMessage')
      ?.onClick
      .listen((event) => captureMessage());
  document
      .querySelector('#btException')
      ?.onClick
      .listen((event) => captureException());
  document
      .querySelector('#btUnhandledException')
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
    (document.querySelector('#messageResult') as HTMLElement?)?.style.display =
        'block';
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
      (document.querySelector('#exceptionResult') as HTMLElement?)
          ?.style
          .display = 'block';
    }
  }
}

Future<void> captureUnhandledException() async {
  (document.querySelector('#unhandledResult') as HTMLElement?)?.style.display =
      'block';

  await buildCard();
}

Future<void> captureCompleteExampleEvent() async {
  print('\nReporting a complete event example: $sdkName');
  final sentryId = await Sentry.captureEvent(event);

  print('Response SentryId: $sentryId');

  if (sentryId != SentryId.empty()) {
    (document.querySelector('#eventResult') as HTMLElement?)?.style.display =
        'block';
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
