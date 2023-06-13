import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:http/http.dart';

String _dsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';
String _authToken = '';
const org = 'sentry-sdks';
const slug = 'sentry-flutter';

void main() async {
  await setupSentry(
    () => runApp(const IntegrationTestApp()),
  );
}

Future<void> setupSentry(AppRunner appRunner, {String? dsn, String? authToken}) async {
  if (dsn != null) {
    _dsn = dsn;
  }
  if (authToken != null) {
    _authToken = authToken;
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
  
  var _result = "--";
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
            Text(_result),
            _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _result = "Sentry Exception E2E: ";
                    _isLoading = true;
                  });
                  await _sentryExceptionE2E();
                },
                child: const Text('Sentry Exception E2E'),
              ),
          ]
        )
      )
    );
  }

  Future<void> _sentryExceptionE2E() async {
    var id = const SentryId.empty();
    try {
      throw Exception('E2E Test Message');
    } catch (e, stacktrace) {
      id = await Sentry.captureException(e, stackTrace: stacktrace);
    }

    final uri = Uri.parse(
      'https://sentry.io/api/0/projects/$org/$slug/events/$id/',
    );
    final event = await _poll(uri);
    if (event != null && _validate(event)) {
      setState(() {
        _result = "Sentry Exception E2E: Success";
        _isLoading = false;
      });
    } else {
      setState(() {
        _result = "Sentry Exception E2E: Failure";
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _poll(Uri url) async {
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
          headers: <String, String>{'Authorization': 'Bearer $_authToken'},
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
        setState(() {
          _result += '.';
        });
      }
    }
    return null;
  }

  bool _validate(Map<String, dynamic> event) {
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
