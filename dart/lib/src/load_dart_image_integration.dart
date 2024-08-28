import '../sentry.dart';
import 'debug_image_extractor.dart';

class LoadDartImageIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    options.addEventProcessor(
        _LoadImageIntegrationEventProcessor(DebugImageExtractor(options)));
    options.sdk.addIntegration('loadDartImageIntegration');
  }
}

class _LoadImageIntegrationEventProcessor implements EventProcessor {
  _LoadImageIntegrationEventProcessor(this._debugImageExtractor);

  final DebugImageExtractor _debugImageExtractor;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (!event.needsSymbolication() || event.stackTrace == null) {
      return event;
    }

    final syntheticImage =
        _debugImageExtractor.extractDebugImageFrom(event.stackTrace!);
    if (syntheticImage == null) {
      return event;
    }

    DebugMeta debugMeta = event.debugMeta ?? DebugMeta();
    final images = debugMeta.images;
    debugMeta = debugMeta.copyWith(images: [...images, syntheticImage]);

    return event.copyWith(debugMeta: debugMeta);
  }
}
