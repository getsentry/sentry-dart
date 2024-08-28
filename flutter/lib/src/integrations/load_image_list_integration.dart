import 'dart:async';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';

/// Loads the native debug image list for stack trace symbolication.
class LoadImageListIntegration extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;

  LoadImageListIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadImageListIntegrationEventProcessor(_native),
    );

    options.sdk.addIntegration('loadImageListIntegration');
  }
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._native);

  final SentryNativeBinding _native;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event.needsSymbolication()) {
      final images = await _native.loadDebugImages();
      if (images != null) {
        return event.copyWith(debugMeta: DebugMeta(images: images));
      }
    }

    return event;
  }
}
