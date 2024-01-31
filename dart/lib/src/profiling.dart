import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
abstract class SentryProfilerFactory {
  SentryProfiler? startProfiler(SentryTransactionContext context);
}

@internal
abstract class SentryProfiler {
  Future<SentryProfileInfo?> finishFor(SentryTransaction transaction);
  void dispose();
}

// See https://develop.sentry.dev/sdk/profiles/
@internal
abstract class SentryProfileInfo {
  SentryEnvelopeItem asEnvelopeItem();
}
