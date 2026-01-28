/// Internal instrumentation API for Sentry packages.
///
/// This library provides a backend-agnostic abstraction for tracing instrumentation,
/// allowing the underlying span implementation to be swapped (e.g., to SentrySpanV2).
///
/// All exports in this file are marked `@internal` and should only be used by
/// Sentry packages, not by end users.
library;

export 'instrumentation_span.dart';
export 'sentry_instrumentation.dart';
export 'span_factory.dart';
export 'transaction_instrumentation.dart';
