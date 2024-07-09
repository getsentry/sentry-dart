@TestOn('vm')
library flutter_test;

import 'dart:convert';

// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test("$FileSystemTransport won't throw", () async {
    final transport = fixture.getSut();
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

  test('$FileSystemTransport returns emptyId if channel throws', () async {
    when(fixture.binding.captureEnvelope(any, false)).thenThrow(Exception());

    final transport = fixture.getSut();
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

  test(
      'sets unhandled exception flag in captureEnvelope to true for unhandled exception',
      () async {
    final transport = fixture.getSut();

    final unhandledException = SentryException(
      mechanism: Mechanism(type: 'UnhandledException', handled: false),
      threadId: 99,
      type: 'Exception',
      value: 'Unhandled exception',
    );
    final event = SentryEvent(exceptions: [unhandledException]);
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');
    final envelope = SentryEnvelope.fromEvent(
      event,
      sdkVersion,
      dsn: fixture.options.dsn,
    );

    await transport.send(envelope);

    verify(fixture.binding.captureEnvelope(captureAny, true)).captured.single
        as Uint8List;
  });

  test(
      'sets unhandled exception flag in captureEnvelope to false for handled exception',
      () async {
    final transport = fixture.getSut();

    final unhandledException = SentryException(
      mechanism: Mechanism(type: 'UnhandledException', handled: true),
      threadId: 99,
      type: 'Exception',
      value: 'Unhandled exception',
    );
    final event = SentryEvent(exceptions: [unhandledException]);
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');
    final envelope = SentryEnvelope.fromEvent(
      event,
      sdkVersion,
      dsn: fixture.options.dsn,
    );

    await transport.send(envelope);

    verify(fixture.binding.captureEnvelope(captureAny, false)).captured.single
        as Uint8List;
  });

  test('$FileSystemTransport asserts the event', () async {
    final transport = fixture.getSut();

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

    final envelopeData =
        verify(fixture.binding.captureEnvelope(captureAny, false))
            .captured
            .single as Uint8List;
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
  final binding = MockSentryNativeBinding();

  FileSystemTransport getSut() {
    return FileSystemTransport(binding, options);
  }
}
