import 'dart:async';

import 'package:meta/meta.dart';

import '../feature_flags/feature_flag.dart';
import '../sentry_envelope.dart';
import '../protocol.dart';

/// A transport is in charge of sending the event/envelope either via http
/// or caching in the disk.
abstract class Transport {
  Future<SentryId?> send(SentryEnvelope envelope);

  @experimental
  Future<Map<String, FeatureFlag>?> fetchFeatureFlags();
}
