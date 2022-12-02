@TestOn('vm')

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:test/test.dart';

import 'mock_sentry_client.dart';

typedef Callback<T> = T Function();

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('uri returns test', () {
    final file = File('test.txt');
    final sut = fixture.getSut(file, tracesSampleRate: 1.0);

    expect(sut.uri.toFilePath(), 'test.txt');
  });

  test('copy wraps with a trace', () async {
    final file = File('test.txt');
    await file.create(recursive: true);
    expect(await file.exists(), true);

    final sut = fixture.getSut(
      file,
      sendDefaultPii: true,
      tracesSampleRate: 1.0,
    );

    final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

    var newFile = await sut.copy('new.txt');

    await tr.finish();

    final exists = await newFile.exists();
    expect(exists, true);

    expect(file.uri.toFilePath(), isNot(newFile.uri.toFilePath()));

    final call = fixture.client.captureTransactionCalls.first;
    final span = call.transaction.spans.first;

    expect(span.context.operation, 'file.copy');
  });
}

class Fixture {
  final client = MockSentryClient();
  final options = SentryOptions(dsn: fakeDsn);
  late Hub hub;

  SentryFile getSut(
    File file, {
    bool sendDefaultPii = false,
    double? tracesSampleRate,
  }) {
    options.sendDefaultPii = sendDefaultPii;
    options.tracesSampleRate = tracesSampleRate;

    hub = Hub(options);
    hub.bindClient(client);
    return SentryFile(file, hub: hub);
  }
}
