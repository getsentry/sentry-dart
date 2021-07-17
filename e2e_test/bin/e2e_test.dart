import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

const _exampleDsn =
    'https://8b83cb94764f4701bee40028c2f29e72@o447951.ingest.sentry.io/5428562';

const _org = 'sdk';
const _projectSlug = 'dart';

const _token = String.fromEnvironment('SENTRY_AUTH_TOKEN');

void main(List<String> arguments) async {
  await Sentry.init((options) {
    options.dsn = _exampleDsn;
  });

  final id = await Sentry.captureMessage('E2E Test Message');
  final url = eventUri(id);
  await waitForEventToShowUp(url);
}

Future<bool> waitForEventToShowUp(Uri url) async {
  var client = Client();

  for (var i = 0; i < 10; i++) {
    final response = await client.get(
      url,
      headers: <String, String>{'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return true;
    }
    await Future.delayed(Duration(seconds: 15));
  }
  return false;
}

Uri eventUri(SentryId id) {
  return Uri.parse(
      'https://sentry.io/api/0/projects/$_org/$_projectSlug/events/$id/');
}
