import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';

Integration<SentryFlutterOptions> createLoadDebugImagesIntegration(
    SentryNativeBinding native) {
  return LoadWebDebugImagesIntegration(native);
}

/// Loads the debug id injected by Sentry tooling e.g Sentry Dart Plugin
/// This is necessary for symbolication of minified js stacktraces via debug ids.
class LoadWebDebugImagesIntegration
    extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;
  static const integrationName = 'LoadWebDebugImages';

  LoadWebDebugImagesIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadDebugIdEventProcessor(_native),
    );
    options.sdk.addIntegration(integrationName);
  }
}

class _LoadDebugIdEventProcessor implements EventProcessor {
  _LoadDebugIdEventProcessor(this._native);

  final SentryNativeBinding _native;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    // ignore: invalid_use_of_internal_member
    final stackTrace = event.stacktrace;
    if (stackTrace == null) {
      return event;
    }
    final debugImages = await _native.loadDebugImages(stackTrace);
    if (debugImages != null) {
      event.debugMeta = DebugMeta(images: debugImages);
    }
    return event;
  }
}
