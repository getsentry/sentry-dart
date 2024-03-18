import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

const _exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

const _org = 'sentry-sdks';
const _projectSlug = 'sentry-flutter';

final _token = Platform.environment['SENTRY_AUTH_TOKEN_E2E'] ?? '';

void main(List<String> arguments) async {
  print('Starting');
  if (_token.trim().isEmpty) {
    print('AUTH TOKEN is not set');
    exit(1);
  }
  final options = SentryOptions(dsn: _exampleDsn)
    // ignore: invalid_use_of_internal_member
    ..automatedTestMode = true;
  await Sentry.init(
    (options) {
      options.dsn = _exampleDsn;
    },
    // ignore: invalid_use_of_internal_member
    options: options,
  );

  var id = SentryId.empty();
  try {
    throw Exception('E2E Test Message');
  } catch (e, stacktrace) {
    id = await Sentry.captureException(e, stackTrace: stacktrace);
  }

  print('Captured exception');
  final url = _eventUri(id);
  final event = await _waitForEventToShowUp(url);
  if (event != null) {
    final allGood = _verifyEvent(event);
    if (allGood) {
      print('success');
      exit(0);
    } else {
      print('Sentry Event does not match expectations');
      exit(1);
    }
  } else {
    print('failed');
    exit(1);
  }
}

bool _verifyEvent(Map<String, dynamic> event) {
  // We check if the configuration which can be set via environment or Dart
  // defines are passed correctly in the application.

  final tags = event['tags'] as List<dynamic>;
  final dist = tags.firstWhere((element) => element['key'] == 'dist');
  if (dist['value'] != '1') {
    print('Dist is not 1');
    return false;
  }
  final environment =
      tags.firstWhere((element) => element['key'] == 'environment');
  if (environment['value'] != 'e2e') {
    print('Environment is not e2e');
    return false;
  }

  return true;
}

Future<Map<String, dynamic>?> _waitForEventToShowUp(Uri url) async {
  final client = Client();

  for (var i = 0; i < 10; i++) {
    print('Try no. $i: Search for event on sentry.io');
    final response = await client.get(
      url,
      headers: <String, String>{'Authorization': 'Bearer $_token'},
    );
    print('${response.statusCode}: ${response.body}');
    if (response.statusCode == 200) {
      // The json does not match what `SentryEvent.fromJson` expects
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    await Future.delayed(Duration(seconds: 15));
  }
  return null;
}

Uri _eventUri(SentryId id) {
  // https://docs.sentry.io/api/events/retrieve-an-event-for-a-project/
  return Uri.parse(
    'https://sentry.io/api/0/projects/$_org/$_projectSlug/events/$id/',
  );
}
