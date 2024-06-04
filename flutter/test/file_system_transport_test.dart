@TestOn('vm')
library flutter_test;

import 'dart:convert';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';

import 'mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler(null);
  });

  test('FileSystemTransport wont throw', () async {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    final transport = fixture.getSut(_channel);
    final event = SentryEvent();
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');

    final envelope = SentryEnvelope.fromEvent(
      event,
      sdkVersion,
      dsn: fixture.options.dsn,
    );
    final sentryId = await transport.send(envelope);

    expect(sentryId, sentryId);
  });

  test('FileSystemTransport returns emptyId if channel throws', () async {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });

    final transport = fixture.getSut(_channel);
    final event = SentryEvent();
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');

    final envelope = SentryEnvelope.fromEvent(
      event,
      sdkVersion,
      dsn: fixture.options.dsn,
    );
    final sentryId = await transport.send(envelope);

    expect(SentryId.empty(), sentryId);
  });

  test('FileSystemTransport asserts the event', () async {
    dynamic arguments;
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      arguments = methodCall.arguments;
    });

    final transport = fixture.getSut(_channel);

    final event =
        SentryEvent(message: SentryMessage('hi I am a special char ◤'));
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');
    final envelope = SentryEnvelope.fromEvent(
      event,
      sdkVersion,
      dsn: fixture.options.dsn,
    );
    await transport.send(envelope);

    final envelopeList = arguments as List;
    final envelopeData = envelopeList.first as Uint8List;
    final envelopeString = utf8.decode(envelopeData);
    final lines = envelopeString.split('\n');
    final envelopeHeader = lines.first;
    final itemHeader = lines[1];
    final item = lines[2];

    final envelopeHeaderMap =
        jsonDecode(envelopeHeader) as Map<String, dynamic>;
    expect(event.eventId.toString(), envelopeHeaderMap['event_id']);

    // just checking its there, the sdk serialization is already unit tested on
    // the dart module
    expect(envelopeHeaderMap.containsKey('sdk'), isNotNull);

    final itemHeaderMap = jsonDecode(itemHeader) as Map<String, dynamic>;

    final eventString = jsonEncode(event.toJson());
    final eventUtf = utf8.encode(eventString);

    expect('application/json', itemHeaderMap['content_type']);
    expect('event', itemHeaderMap['type']);
    expect(eventUtf.length, itemHeaderMap['length']);

    expect(item, eventString);
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  FileSystemTransport getSut(MethodChannel channel) {
    return FileSystemTransport(channel, options);
  }
}
