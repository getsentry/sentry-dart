import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:http/http.dart';

String _dsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

void main() async {
  await setupSentry(
    () => runApp(const IntegrationTestApp()),
  );
}

Future<void> setupSentry(AppRunner appRunner, {String? dsn}) async {
  if (dsn != null) {
    _dsn = dsn;
  }
  await SentryFlutter.init((options) {
    options.dsn = _dsn;
    options.debug = true;
    options.dist = '1';
    options.environment = 'integration';
  }, appRunner: appRunner);
}

class IntegrationTestApp extends StatelessWidget {
  const IntegrationTestApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Integration Test App',
      home: IntegrationTestWidget(),
    );
  }
}

class IntegrationTestWidget extends StatefulWidget {
  const IntegrationTestWidget({super.key});

  @override
  State<IntegrationTestWidget> createState() => _IntegrationTestState();
}

class _IntegrationTestState extends State<IntegrationTestWidget> {
  _IntegrationTestState();
  
  var _output = "--";
  var _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Test App'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              _output,
              key: const Key('output'),
            ),
            _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                onPressed: () async => await _captureException(),
                child: const Text('captureException'),
              ),
          ]
        )
      )
    );
  }

  Future<void> _captureException() async {
    setState(() {
      _isLoading = true;
    });
    try {
      throw Exception('captureException');
    } catch (e, stacktrace) {
      final id = await Sentry.captureException(e, stackTrace: stacktrace);
      setState(() {
        _output = id.toString();
        _isLoading = false;
      });
    }
  }
}
