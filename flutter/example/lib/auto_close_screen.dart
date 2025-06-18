import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'main.dart';

/// This screen is only used to demonstrate how route navigation works.
/// Init will create a child span and pop the screen after 3 seconds.
/// Afterwards the transaction should be seen on the performance page.
class AutoCloseScreen extends StatefulWidget {
  const AutoCloseScreen({super.key});

  @override
  AutoCloseScreenState createState() => AutoCloseScreenState();
}

class AutoCloseScreenState extends State<AutoCloseScreen> {
  @override
  void initState() {
    super.initState();
    _doComplexOperationThenClose();
  }

  Future<void> _doComplexOperationThenClose() async {
    final dio = Dio();
    dio.addSentry();
    try {
      // Add a bit of delay to demonstrate TTFD
      await Future.delayed(const Duration(seconds: 3));
      await dio.get<String>(exampleUrl);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    if (mounted) {
      SentryDisplayWidget.of(context).reportFullyDisplayed();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delayed Screen'),
      ),
      body: const Center(
        child: Text(
          'This screen will automatically close in a few seconds.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
