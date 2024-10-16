import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';

const _org = 'sentry-sdks';
const _projectSlug = 'sentry-flutter';
const _exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';
const _token =
    String.fromEnvironment('SENTRY_AUTH_TOKEN_E2E', defaultValue: '');
//  flutter build apk --dart-define=SENTRY_AUTH_TOKEN_E2E=$SENTRY_AUTH_TOKEN_E2E works

Future<void> main() async {
  if (_token.trim().isEmpty) {
    print('AUTH TOKEN is not set');
    exit(1);
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _exampleDsn;
      // ignore: invalid_use_of_internal_member
      options.automatedTestMode = true;
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter E2E',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter E2E Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            HttpRequestExample(),
          ],
        ),
      ),
    );
  }
}

class HttpRequestExample extends StatefulWidget {
  const HttpRequestExample({super.key});

  @override
  HttpRequestExampleState createState() => HttpRequestExampleState();
}

class HttpRequestExampleState extends State<HttpRequestExample> {
  String _responseText = 'Click the button to make a request';

  Future<void> _makeRequest() async {
    setState(() {
      _responseText = 'Sending exception to Sentry...';
    });

    var id = const SentryId.empty();
    try {
      throw Exception('E2E Test Exception');
    } catch (e, stacktrace) {
      id = await Sentry.captureException(e, stackTrace: stacktrace);
    }

    final url = _eventUri(id);
    final event = await _waitForEventToShowUp(url);

    if (event != null) {
      setState(() {
        _responseText = 'Event successfully received';
      });
    } else {
      setState(() {
        _responseText = 'Failed to receive event';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _makeRequest,
          child: const Text(
            'Capture Exception',
            semanticsLabel: 'Capture Exception',
          ),
        ),
        Text(
          _responseText,
          semanticsLabel: _responseText,
        ),
      ],
    );
  }
}

Future<Map<String, dynamic>?> _waitForEventToShowUp(Uri url) async {
  final client = Client();

  for (var i = 0; i < 10; i++) {
    print('Try no. $i: Search for event on sentry.io');
    final response = await client.get(
      url,
      headers: <String, String>{'Authorization': 'Bearer $_token'},
    );
    print('Response: ${response.statusCode}: ${response.body}');
    if (response.statusCode == 200) {
      // The json does not match what `SentryEvent.fromJson` expects
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    await Future.delayed(const Duration(seconds: 15));
  }
  return null;
}

Uri _eventUri(SentryId id) {
  // https://docs.sentry.io/api/events/retrieve-an-event-for-a-project/
  return Uri.parse(
    'https://sentry.io/api/0/projects/$_org/$_projectSlug/events/$id/',
  );
}
