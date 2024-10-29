import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// High-level interface for Sentry JS SDK operations.
///
/// Handles Flutter-specific types and provides type safe access to Sentry JS.
@internal
abstract class SentryWebBinding {
  /// Initializes the SDK with Flutter options.
  Future<void> init(SentryFlutterOptions options);

  /// Captures and sends an envelope to Sentry.
  Future<void> captureEnvelope(SentryEnvelope envelope);

  /// Flushes pending replay events.
  Future<void> flushReplay();

  /// Gets current replay ID if session replay is active.
  Future<SentryId?> getReplayId();

  /// Closes the SDK and cleans up resources.
  Future<void> close();
}
