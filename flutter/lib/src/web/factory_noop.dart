import '../../sentry_flutter.dart';
import '../web/sentry_web_binding.dart';

class NoOpWebInterop implements SentryWebBinding {
  @override
  Future<void> captureEnvelope(SentryEnvelope envelope) async {}

  @override
  Future<void> captureEvent(SentryEvent event) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> init(SentryFlutterOptions options) async {}

  @override
  Future<void> flushReplay() async {}

  @override
  Future<SentryId> getReplayId() {
    return Future.value(SentryId.empty());
  }

  @override
  Future<void> startReplay() async {}
}

SentryWebBinding createBinding(SentryFlutterOptions options) =>
    NoOpWebInterop();
