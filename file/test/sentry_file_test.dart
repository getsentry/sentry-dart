// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library file_test;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:sentry_file/src/version.dart';
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
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _asserBreadcrumb(bool async) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.copy');
      expect(breadcrumb?.data?['file.size'], 7);
      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.message, 'testfile.txt');
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/testfile.txt'),
          true);
    }

    test('async', () async {
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
      _asserBreadcrumb(true);

      await newFile.delete();
    });

    test('sync', () async {
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
      _asserBreadcrumb(false);

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
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb(bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.write');
      expect(breadcrumb?.data?['file.size'], size);
      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.message, 'testfile_create.txt');
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/testfile_create.txt'),
          true);
    }

    test('async', () async {
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
      _assertBreadcrumb(true);

      await newFile.delete();
    });

    test('sync', () async {
      final file = File('test_resources/testfile_create.txt');
      expect(await file.exists(), false);

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.createSync();

      await tr.finish();

      expect(sut.existsSync(), true);

      _assertSpan(false);
      _assertBreadcrumb(false);

      sut.deleteSync();
    });
  });

  group('$SentryFile delete', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.delete');
      expect(span.data['file.size'], size);
      expect(span.data['file.async'], async);
      expect(span.context.description, 'testfile_delete.txt');
      expect(
          (span.data['file.path'] as String)
              .endsWith('test_resources/testfile_delete.txt'),
          true);
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb(bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.delete');
      expect(breadcrumb?.data?['file.size'], size);
      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.message, 'testfile_delete.txt');
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/testfile_delete.txt'),
          true);
    }

    test('async', () async {
      final file = File('test_resources/testfile_delete.txt');
      await file.create();
      expect(await file.exists(), true);

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = await sut.delete();

      await tr.finish();

      expect(await newFile.exists(), false);

      _assertSpan(true);
      _assertBreadcrumb(true);
    });

    test('sync', () async {
      final file = File('test_resources/testfile_delete.txt');
      file.createSync();
      expect(file.existsSync(), true);

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.deleteSync();

      await tr.finish();

      expect(sut.existsSync(), false);

      _assertSpan(false);
      _assertBreadcrumb(false);
    });
  });

  group('$SentryFile open', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan() {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.open');
      expect(span.data['file.size'], 3535);
      expect(span.data['file.async'], true);
      expect(span.context.description, 'sentry.png');
      expect(
          (span.data['file.path'] as String)
              .endsWith('test_resources/sentry.png'),
          true);
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb() {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.open');
      expect(breadcrumb?.data?['file.size'], 3535);
      expect(breadcrumb?.data?['file.async'], true);
      expect(breadcrumb?.message, 'sentry.png');
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/sentry.png'),
          true);
    }

    test('async', () async {
      final file = File('test_resources/sentry.png');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = await sut.open();

      await tr.finish();

      await newFile.close();

      _assertSpan();
      _assertBreadcrumb();
    });
  });

  group('$SentryFile read', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(String fileName, bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.read');
      expect(span.data['file.size'], size);
      expect(span.data['file.async'], async);
      expect(span.context.description, fileName);
      expect(
          (span.data['file.path'] as String)
              .endsWith('test_resources/$fileName'),
          true);
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb(String fileName, bool async, {int? size = 0}) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.read');
      expect(breadcrumb?.data?['file.size'], size);
      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.message, fileName);
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/$fileName'),
          true);
    }

    test('as bytes async', () async {
      final file = File('test_resources/sentry.png');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      await sut.readAsBytes();

      await tr.finish();

      _assertSpan('sentry.png', true, size: 3535);
      _assertBreadcrumb('sentry.png', true, size: 3535);
    });

    test('as bytes sync', () async {
      final file = File('test_resources/sentry.png');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.readAsBytesSync();

      await tr.finish();

      _assertSpan('sentry.png', false, size: 3535);
      _assertBreadcrumb('sentry.png', false, size: 3535);
    });

    test('lines async', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      await sut.readAsLines();

      await tr.finish();

      _assertSpan('testfile.txt', true, size: 7);
      _assertBreadcrumb('testfile.txt', true, size: 7);
    });

    test('lines sync', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.readAsLinesSync();

      await tr.finish();

      _assertSpan('testfile.txt', false, size: 7);
      _assertBreadcrumb('testfile.txt', false, size: 7);
    });

    test('string async', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      await sut.readAsString();

      await tr.finish();

      _assertSpan('testfile.txt', true, size: 7);
      _assertBreadcrumb('testfile.txt', true, size: 7);
    });

    test('string sync', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.readAsStringSync();

      await tr.finish();

      _assertSpan('testfile.txt', false, size: 7);
      _assertBreadcrumb('testfile.txt', false, size: 7);
    });
  });

  group('$SentryFile rename', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(bool async, String name) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.context.operation, 'file.rename');
      expect(span.data['file.size'], 0);
      expect(span.data['file.async'], async);
      expect(span.context.description, name);
      expect(
          (span.data['file.path'] as String).endsWith('test_resources/$name'),
          true);
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb(bool async, String name) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.category, 'file.rename');
      expect(breadcrumb?.data?['file.size'], 0);
      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.message, name);
      expect(
          (breadcrumb?.data?['file.path'] as String)
              .endsWith('test_resources/$name'),
          true);
    }

    test('async', () async {
      final file = File('test_resources/old_name.txt');
      await file.create();

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = await sut.rename('test_resources/new_name.txt');

      await tr.finish();

      expect(await file.exists(), false);
      expect(await newFile.exists(), true);

      expect(sut.uri.toFilePath(), isNot(newFile.uri.toFilePath()));

      _assertSpan(true, 'old_name.txt');
      _assertBreadcrumb(true, 'old_name.txt');

      await newFile.delete();
    });

    test('sync', () async {
      final file = File('test_resources/old_name.txt');
      file.createSync();

      final sut = fixture.getSut(
        file,
        sendDefaultPii: true,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      final newFile = sut.renameSync('test_resources/testfile_copy.txt');

      await tr.finish();

      expect(file.existsSync(), false);
      expect(newFile.existsSync(), true);

      expect(sut.uri.toFilePath(), isNot(newFile.uri.toFilePath()));

      _assertSpan(false, 'old_name.txt');
      _assertBreadcrumb(false, 'old_name.txt');

      newFile.deleteSync();
    });
  });

  group('$SentryOptions config', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void _assertSpan(bool async) {
      final call = fixture.client.captureTransactionCalls.first;
      final span = call.transaction.spans.first;

      expect(span.data['file.async'], async);
      expect(span.data['file.path'], null);
      expect(span.origin, SentryTraceOrigins.autoFile);
    }

    void _assertBreadcrumb(bool async) {
      final call = fixture.client.captureTransactionCalls.first;
      final breadcrumb = call.scope?.breadcrumbs.first;

      expect(breadcrumb?.data?['file.async'], async);
      expect(breadcrumb?.data?['file.path'], null);
    }

    test('does not add file path if sendDefaultPii is disabled async',
        () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      await sut.readAsBytes();

      await tr.finish();

      _assertSpan(true);
      _assertBreadcrumb(true);
    });

    test('does not add file path if sendDefaultPii is disabled sync', () async {
      final file = File('test_resources/testfile.txt');

      final sut = fixture.getSut(
        file,
        tracesSampleRate: 1.0,
      );

      final tr = fixture.hub.startTransaction('name', 'op', bindToScope: true);

      sut.readAsBytesSync();

      await tr.finish();

      _assertSpan(false);
      _assertBreadcrumb(false);
    });

    test('add SentryFileTracing integration', () async {
      final file = File('test_resources/testfile.txt');

      fixture.getSut(
        file,
        tracesSampleRate: 1.0,
      );

      expect(fixture.hub.options.sdk.integrations.contains('SentryFileTracing'),
          true);
    });

    test('addSentry adds package to sdk', () {
      final file = File('test_resources/testfile.txt');

      fixture.getSut(
        file,
        tracesSampleRate: 1.0,
      );

      expect(
        fixture.hub.options.sdk.packages
            .where((it) => it.name == packageName && it.version == sdkVersion)
            .length,
        1,
      );
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
