import 'dart:io';

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

const _exampleDsn =
    'https://8b83cb94764f4701bee40028c2f29e72@o447951.ingest.sentry.io/5428562';

const _org = 'sentry-sdks';
const _projectSlug = 'sentry-flutter';

final _token = Platform.environment['SENTRY_AUTH_TOKEN'] ?? '';

void main(List<String> arguments) async {
  print('Starting');
  if (_token.trim().isEmpty) {
    print('AUTH TOKEN is not set');
    exit(1);
  }
  await Sentry.init((options) {
    options.dsn = _exampleDsn;
  });

  var id = SentryId.empty();
  try {
    throw Exception('E2E Test Message');
  } catch (e, stacktrace) {
    id = await Sentry.captureException(e, stackTrace: stacktrace);
  }

  print('Captured exception');
  final url = _eventUri(id);
  final found = await _waitForEventToShowUp(url);
  if (found) {
    print('success');
    exit(0);
  } else {
    print('failed');
    exit(1);
  }
}

Future<bool> _waitForEventToShowUp(Uri url) async {
  final client = Client();

  for (var i = 0; i < 10; i++) {
    print('Try no. $i: Search for event on sentry.io');
    final response = await client.get(
      url,
      headers: <String, String>{'Authorization': 'Bearer $_token'},
    );
    print('${response.statusCode}: ${response.body}');
    if (response.statusCode == 200) {
      return true;
    }
    await Future.delayed(Duration(seconds: 15));
  }
  return false;
}

Uri _eventUri(SentryId id) {
  // https://docs.sentry.io/api/events/retrieve-an-event-for-a-project/
  return Uri.parse(
    'https://sentry.io/api/0/projects/$_org/$_projectSlug/events/$id/',
  );
}
