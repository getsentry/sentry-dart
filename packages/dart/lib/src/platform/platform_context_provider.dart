import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'io_platform_context_provider.dart'
    if (dart.library.js_interop) 'web_platform_context_provider.dart';

/// Supplies a fresh [Contexts] describing the current platform.
///
/// Implementations read from `dart:io` (native) or `package:web` (web) and
/// may cache slow-to-detect values. Intended for use by enrichers that
/// merge platform data into events, and by telemetry callbacks that
/// project the same data onto span/log/metric attributes.
@internal
abstract class PlatformContextProvider {
  factory PlatformContextProvider(SentryOptions options) =>
      platformContextProvider(options);

  /// Returns a fresh [Contexts] populated with platform-derived fields.
  ///
  /// Every call returns a new instance; callers that need to merge into
  /// an existing [Contexts] should do so themselves.
  Future<Contexts> buildContexts();
}
