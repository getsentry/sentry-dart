import 'package:sentry/sentry.dart';

abstract class ImageLoadingIntegration extends Integration<SentryOptions> {}

class DartImageLoadingIntegration implements ImageLoadingIntegration {
  @override
  void call(Hub hub, SentryOptions options) {
    options.addEventProcessor(
        _LoadImageListIntegrationEventProcessor(DartSymbolizer(options)));
    options.sdk.addIntegration('loadImageIntegration');
  }

  @override
  void close() {}
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._symbolizer);

  final DartSymbolizer _symbolizer;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event.stackTrace == null) {
      return event;
    }
    print('stacktrace: ${event.stackTrace}');
    final image = _symbolizer.toImage(event.stackTrace!);
    print('image: $image');
    if (image == null) {
      return event;
    }
    final debugMeta = DebugMeta(images: [image]);
    event = event.copyWith(debugMeta: debugMeta);
    return event;
  }
}
