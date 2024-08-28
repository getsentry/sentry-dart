import '../sentry.dart';

class DartImageLoadingIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    options.addEventProcessor(
        _LoadImageListIntegrationEventProcessor(DebugImageExtractor(options)));
    options.sdk.addIntegration('loadImageIntegration');
  }

  @override
  void close() {}
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._symbolizer);

  final DebugImageExtractor _symbolizer;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event.stackTrace == null) {
      return event;
    }
    final image = _symbolizer.toImage(event.stackTrace!);
    if (image == null) {
      return event;
    }
    event = event.copyWith(debugMeta: DebugMeta(images: [image]));
    return event;
  }
}
