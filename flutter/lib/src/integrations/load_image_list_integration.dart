import 'dart:async';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';

/// Loads the native debug image list for stack trace symbolication.
class LoadImageListIntegration extends Integration<SentryFlutterOptions> {
  /// TODO: rename to LoadNativeDebugImagesIntegration in the next major version
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
    final stackTrace = event.stacktrace;

    // if the stacktrace has native frames, we load native debug images.
    if (stackTrace != null &&
        stackTrace.frames.any((frame) => 'native' == frame.platform)) {
      final images = await _native.loadDebugImages(stackTrace);
      if (images != null) {
        return event.copyWith(debugMeta: DebugMeta(images: images));
      }
    }

    return event;
  }
}
