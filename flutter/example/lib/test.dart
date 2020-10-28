import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

// Wrap your 'runApp(MyApp())' as follows:

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) async {
    await Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  };
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    throw UnimplementedError();
  }
}
