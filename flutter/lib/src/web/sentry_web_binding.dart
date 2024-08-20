import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Provide typed methods to access web layer.
@internal
abstract class SentryWebBinding {
  Future<void> init(SentryFlutterOptions options);

  Future<void> captureEnvelope(SentryEnvelope envelope);

  Future<void> captureEvent(SentryEvent event);

  Future<void> flushReplay();

  Future<void> startReplay();

  Future<SentryId> getReplayId();

  Future<void> close();
}
