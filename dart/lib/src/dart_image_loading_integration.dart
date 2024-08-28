import 'package:meta/meta.dart';

import '../sentry.dart';
import 'debug_image_extractor.dart';

class DartImageLoadingIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    options.addEventProcessor(
        _LoadImageIntegrationEventProcessor(DebugImageExtractor(options)));
    options.sdk.addIntegration('loadImageIntegration');
  }

  @override
  void close() {}
}

class _LoadImageIntegrationEventProcessor implements EventProcessor {
  _LoadImageIntegrationEventProcessor(this._debugImageExtractor);

  final DebugImageExtractor _debugImageExtractor;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (!event.needsSymbolication()) {
      return event;
    }
    if (event.stackTrace == null) {
      return event;
    }
    final syntheticImage =
        _debugImageExtractor.extractFrom(event.stackTrace!).toDebugImage();
    if (syntheticImage == null) {
      return event;
    }
    event = event.copyWith(debugMeta: DebugMeta(images: [syntheticImage]));
    return event;
  }
}

@internal
extension NeedsSymbolication on SentryEvent {
  bool needsSymbolication() {
    if (this is SentryTransaction) {
      return false;
    }
    final frames = _getStacktraceFrames();
    if (frames == null) {
      return false;
    }
    return frames.any((frame) => 'native' == frame?.platform);
  }

  Iterable<SentryStackFrame?>? _getStacktraceFrames() {
    if (exceptions?.isNotEmpty == true) {
      return exceptions?.first.stackTrace?.frames;
    }
    if (threads?.isNotEmpty == true) {
      var stacktraces = threads?.map((e) => e.stacktrace);
      return stacktraces
          ?.where((element) => element != null)
          .expand((element) => element!.frames);
    }
    return null;
  }
}
