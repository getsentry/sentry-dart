import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

/// This is an exampleUrl that will be used to demonstrate how http requests are captured.
const String exampleUrl = 'https://jsonplaceholder.typicode.com/todos/';

const _methodChannel = MethodChannel('example.flutter.sentry.io');

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool isIntegrationTest = false;

Future<void> execute(String method) async {
  await _methodChannel.invokeMethod(method);
}
