import 'package:http/http.dart';
import 'package:sentry/src/base.dart';
import 'package:sentry/src/version.dart';
import 'package:test/test.dart';

typedef Answer = dynamic Function(Invocation invocation);

class MockClient implements Client {
  Answer _answer;

  void answerWith(Answer answer) {
    _answer = answer;
  }

  noSuchMethod(Invocation invocation) {
    return _answer(invocation);
  }
}

void testDsn(SentryClientBase client, String dsn, {bool withSecret = true}) {
  expect(client.dsnUri, Uri.parse(dsn));
  expect(client.postUri, 'https://sentry.example.com/api/1/store/');
  expect(client.publicKey, 'public');
  expect(client.secretKey, withSecret ? 'secret' : null);
  expect(client.projectId, '1');
}

void testHeaders(
  Map<String, String> headers,
  ClockProvider fakeClockProvider, {
  bool withUserAgent = true,
  bool compressPayload = true,
  bool withSecret = true,
}) {
  final Map<String, String> expectedHeaders = <String, String>{
    'Content-Type': 'application/json',
    'X-Sentry-Auth': 'Sentry sentry_version=6, '
        'sentry_client=${SentryClientBase.sentryClient}, '
        'sentry_timestamp=${fakeClockProvider().millisecondsSinceEpoch}, '
        'sentry_key=public'
  };

  if (withSecret) {
    expectedHeaders['X-Sentry-Auth'] += ', '
        'sentry_secret=secret';
  }

  if (withUserAgent) expectedHeaders['User-Agent'] = '$sdkName/$sdkVersion';

  if (compressPayload) expectedHeaders['Content-Encoding'] = 'gzip';

  expect(headers, expectedHeaders);
}
