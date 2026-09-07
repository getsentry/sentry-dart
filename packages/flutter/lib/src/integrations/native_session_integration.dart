// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

@internal
class NativeSessionIntegration implements Integration<SentryFlutterOptions> {
  static const integrationName = 'NativeSession';
  final SentryNativeBinding _native;
  SentryOptions? _options;

  NativeSessionIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.enableAutoSessionTracking) {
      internalLogger.info('$integrationName: disabled, skipping setup');
      return;
    }

    _options = options;
    options.lifecycleRegistry.registerCallback<OnEventSampledOut>(
      _updateSessionForSampledOutEvent,
    );
    options.sdk.addIntegration(integrationName);
  }

  @override
  void close() {
    _options?.lifecycleRegistry.removeCallback<OnEventSampledOut>(
      _updateSessionForSampledOutEvent,
    );
    _options = null;
  }

  Future<void> _updateSessionForSampledOutEvent(
    OnEventSampledOut lifecycleEvent,
  ) async {
    final isUnhandled = lifecycleEvent.event.exceptions?.any(
      (exception) => exception.mechanism?.handled == false,
    );
    if (isUnhandled != true) {
      return;
    }

    try {
      await _native.updateSessionForDroppedEventNonTerminating(true);
    } catch (exception, stackTrace) {
      internalLogger.warning(
        '$integrationName: failed to update native session',
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
