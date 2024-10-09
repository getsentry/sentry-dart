import 'dart:async';
import 'dart:io';

import 'package:sentry/sentry.dart';
import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';

// ignore: implementation_imports
import 'package:sentry/src/load_dart_debug_images_integration.dart'
    show NeedsSymbolication;

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
    if (event.needsSymbolication()) {
      Set<String> instructionAddresses = {};
      var exceptions = event.exceptions;
      if (exceptions != null && exceptions.isNotEmpty) {
        for (var e in exceptions) {
          if (e.stackTrace != null) {
            instructionAddresses.addAll(
              _collectImageAddressesFromStackTrace(e.stackTrace!),
            );
          }
        }
      }

      if (event.threads != null && event.threads!.isNotEmpty) {
        for (var thread in event.threads!) {
          if (thread.stacktrace != null) {
            instructionAddresses.addAll(
              _collectImageAddressesFromStackTrace(thread.stacktrace!),
            );
          }
        }
      }

      final images = await _native.loadDebugImages(instructionAddresses);
      if (images != null) {
        return event.copyWith(debugMeta: DebugMeta(images: images));
      }
    }

    return event;
  }

  Set<String> _collectImageAddressesFromStackTrace(SentryStackTrace trace) {
    Set<String> instructionAddresses = {};
    for (var frame in trace.frames) {
      if (frame.imageAddr != null) {
        instructionAddresses.add(frame.instructionAddr!);
      }
    }
    return instructionAddresses;
  }
}
