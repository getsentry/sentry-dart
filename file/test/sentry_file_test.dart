@TestOn('vm')

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:test/test.dart';

import 'mock_sentry_client.dart';

typedef Callback<T> = T Function();

void main() {
  group('$SentryFile copy', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(bool async) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.copy');
      expect(span.data['file.size'], 7);
      expect(span.data['file.async'], async);
      expect(span.context.description, 'testfile.txt');
      expect(
          (span.data['file.path'] as String)
              .endsWith('test_resources/testfile.txt'),
          true);
    }

    test('copy async', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = await sut.copy('test_resources/testfile_copy.txt');

      await tr.finish();

      expect(await newFile.exists(), true);

      expect(sut.uri.toFilePath(), isNot(newFile.uri.toFilePath()));

      _assertSpan(true);

      await newFile.delete();
    });

    test('copy sync', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = sut.copySync('test_resources/testfile_copy.txt');

      await tr.finish();

      expect(newFile.existsSync(), true);

      expect(sut.uri.toFilePath(), isNot(newFile.uri.toFilePath()));

      _assertSpan(false);

      newFile.deleteSync();
    });
  });

  group('$SentryFile create', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.write');
      expect(span.data['file.size'], size);
      expect(span.data['file.async'], async);
      expect(span.context.description, 'testfile_create.txt');
      expect(
          (span.data['file.path'] as String)
              .endsWith('test_resources/testfile_create.txt'),
          true);
    }

    test('create async', () async {
      final file = File('test_resources/testfile_create.txt');
      expect(await file.exists(), false);

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = await sut.create();

      await tr.finish();

      expect(await newFile.exists(), true);

      _assertSpan(true);

      await newFile.delete();
    });

    test('create sync', () async {
      final file = File('test_resources/testfile_create.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.createSync();

      await tr.finish();

      expect(sut.existsSync(), true);

      _assertSpan(false, size: null);

      sut.deleteSync();
    });
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
