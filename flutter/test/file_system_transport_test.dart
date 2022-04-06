import 'dart:convert';
import 'dart:typed_data';

import 'package:mockito/mockito.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';

import 'mocks.mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  test('FileSystemTransport wont throw', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

    when(fixture.recorder.flush()).thenReturn(null);

    final transport = fixture.getSut(_channel);
    final event = SentryEvent();
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');

    final envelope = SentryEnvelope.fromEvent(event, sdkVersion);
    final sentryId = await transport.send(envelope);

    expect(sentryId, sentryId);
  });

  test('FileSystemTransport returns emptyId if channel throws', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });

    when(fixture.recorder.flush()).thenReturn(null);

    final transport = fixture.getSut(_channel);
    final event = SentryEvent();
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');

    final envelope = SentryEnvelope.fromEvent(event, sdkVersion);
    final sentryId = await transport.send(envelope);

    expect(SentryId.empty(), sentryId);
  });

  test('FileSystemTransport asserts the event', () async {
    dynamic arguments;
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      arguments = methodCall.arguments;
    });

    when(fixture.recorder.flush()).thenReturn(null);

    final transport = fixture.getSut(_channel);

    final event =
        SentryEvent(message: SentryMessage('hi I am a special char ◤'));
    final sdkVersion =
        SdkVersion(name: 'fixture-sdkName', version: 'fixture-sdkVersion');
    final envelope = SentryEnvelope.fromEvent(event, sdkVersion);
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

  test('flush called', () async {
    final sut = fixture.getSut(_channel);

    final sentryEvent = SentryEvent();
    final envelope = SentryEnvelope.fromEvent(
      sentryEvent,
      fixture.options.sdk,
    );

    when(fixture.recorder.flush()).thenReturn(null);

    await sut.send(envelope);

    verify(fixture.recorder.flush());
  });

  test('client report added to envelope', () async {
    final mockEnvelope = MockSentryEnvelope();
    when(mockEnvelope.envelopeStream(any)).thenAnswer((_) => Stream.empty());

    final sut = fixture.getSut(_channel);

    final clientReport = ClientReport(
      DateTime(0),
      [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
    );
    when(fixture.recorder.flush()).thenReturn(clientReport);

    await sut.send(mockEnvelope);

    verify(mockEnvelope.addClientReport(clientReport));
  });
}

class Fixture {
  final options = SentryOptions(dsn: '');
  final recorder = MockClientReportRecorder();

  FileSystemTransport getSut(MethodChannel channel) {
    return FileSystemTransport(channel, options, recorder);
  }
}
