import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
abstract class ProfilerFactory {
  Profiler startProfiling(SentryTransactionContext context);
}

@internal
abstract class Profiler {
  Future<ProfileInfo> finishFor(SentryTransaction transaction);
  void dispose();
}

// See https://develop.sentry.dev/sdk/profiles/
@internal
abstract class ProfileInfo {
  FutureOr<SentryEnvelopeItem> asEnvelopeItem();
}
