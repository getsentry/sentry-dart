import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../dart/test/mocks/mock_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final transport = MockTransport();

  setUp(() async {
    await SentryFlutter.init((options) {
      // ignore: invalid_use_of_internal_member
      options.devMode = true;
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
    expect(await envelope.items[0].header.length(), greaterThan(0));
    expect(envelope.items[1].header.type, "profile");
    expect(await envelope.items[1].header.length(), greaterThan(0));

    final txJson = utf8.decode(await envelope.items[0].dataFactory());
    final txData = json.decode(txJson) as Map<String, dynamic>;

    final profileJson = utf8.decode(await envelope.items[1].dataFactory());
    final profileData = json.decode(profileJson) as Map<String, dynamic>;

    expect(txData["event_id"], isNotNull);
    expect(txData["event_id"], profileData["transaction"]["id"]);
    expect(txData["contexts"]["trace"]["trace_id"], isNotNull);
    expect(txData["contexts"]["trace"]["trace_id"],
        profileData["transaction"]["trace_id"]);
    expect(profileData["debug_meta"]["images"], isNotEmpty);
    expect(profileData["profile"]["thread_metadata"], isNotEmpty);
    expect(profileData["profile"]["samples"], isNotEmpty);
    expect(profileData["profile"]["stacks"], isNotEmpty);
    expect(profileData["profile"]["frames"], isNotEmpty);
  });
}
