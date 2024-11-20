import 'dart:async';

import 'package:sentry/sentry.dart';
// ignore: implementation_imports
import 'package:sentry/src/load_dart_debug_images_integration.dart';

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
      _LoadImageListIntegrationEventProcessor(options, _native),
    );

    options.sdk.addIntegration('loadImageListIntegration');
  }
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._options, this._native);

  final SentryFlutterOptions _options;
  final SentryNativeBinding _native;

  late final _dartProcessor = LoadImageIntegrationEventProcessor(_options);

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    // ignore: invalid_use_of_internal_member
    final stackTrace = event.stacktrace;

    // if the stacktrace has native frames, we load native debug images.
    if (stackTrace != null &&
        stackTrace.frames.any((frame) => 'native' == frame.platform)) {
      var images = await _native.loadDebugImages(stackTrace);

      // On windows, we need to add the ELF debug image of the AOT code.
      // See https://github.com/flutter/flutter/issues/154840
      if (_options.platformChecker.platform.isWindows) {
        final debugImage = _dartProcessor.getAppDebugImage(stackTrace);
        if (debugImage != null) {
          images ??= List.empty();
          images.add(debugImage);
        }
      }
      if (images != null) {
        return event.copyWith(debugMeta: DebugMeta(images: images));
      }
    }

    return event;
  }
}
