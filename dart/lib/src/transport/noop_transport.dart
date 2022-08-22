import 'dart:async';

import '../feature_flags/feature_flag.dart';
import '../sentry_envelope.dart';

import '../protocol.dart';
import 'transport.dart';

class NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;

  @override
  Future<Map<String, FeatureFlag>?> fetchFeatureFlags() async => null;
}
