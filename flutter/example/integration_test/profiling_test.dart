import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../packages/dart/test/mocks/mock_transport.dart';

void main() {
  final transport = MockTransport();

  setUp(() async {
    await SentryFlutter.init((options) {
      // ignore: invalid_use_of_internal_member
      options.automatedTestMode = true;
      options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
      options.debug = true;
      options.transport = transport;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
    });
  });

  tearDown(() async {
    await Sentry.close();
    transport.reset();
  });

  test('native binding is initialized', () async {
    // ignore: invalid_use_of_internal_member
    expect(SentryFlutter.native, isNotNull);
  });

  test('profile is captured', () async {
    final tx = Sentry.startTransaction("name", "op");
    await Future.delayed(const Duration(milliseconds: 1000));
    await tx.finish();
    expect(transport.calls, 1);

    final envelope = transport.envelopes.first;
    expect(envelope.items.length, 2);
    expect(envelope.items[0].header.type, "transaction");
    expect(envelope.items[1].header.type, "profile");

    final txData = await envelope.items[0].dataFactory();
    expect(txData.length, greaterThan(0));

    final txJson = utf8.decode(txData);
    final txMap = json.decode(txJson) as Map<String, dynamic>;

    final profileData = await envelope.items[1].dataFactory();
    expect(profileData.length, greaterThan(0));

    final profileJson = utf8.decode(profileData);
    final profileMap = json.decode(profileJson) as Map<String, dynamic>;

    expect(txMap["event_id"], isNotNull);
    expect(txMap["event_id"], profileMap["transaction"]["id"]);
    expect(txMap["contexts"]["trace"]["trace_id"], isNotNull);
    expect(txMap["contexts"]["trace"]["trace_id"],
        profileMap["transaction"]["trace_id"]);
    expect(profileMap["debug_meta"]["images"], isNotEmpty);
    expect(profileMap["profile"]["thread_metadata"], isNotEmpty);
    expect(profileMap["profile"]["samples"], isNotEmpty);
    expect(profileMap["profile"]["stacks"], isNotEmpty);
    expect(profileMap["profile"]["frames"], isNotEmpty);
  },
      skip: (Platform.isMacOS || Platform.isIOS)
          ? false
          : "Profiling is not supported on this platform");
}
