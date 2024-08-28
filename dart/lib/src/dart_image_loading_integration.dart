import 'package:meta/meta.dart';

import '../sentry.dart';
import 'debug_info_extractor.dart';

class DartImageLoadingIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    options.addEventProcessor(
        _LoadImageIntegrationEventProcessor(DebugInfoExtractor(options)));
    options.sdk.addIntegration('loadImageIntegration');
  }

  @override
  void close() {}
}

class _LoadImageIntegrationEventProcessor implements EventProcessor {
  _LoadImageIntegrationEventProcessor(this._debugImageExtractor);

  final DebugInfoExtractor _debugImageExtractor;

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
