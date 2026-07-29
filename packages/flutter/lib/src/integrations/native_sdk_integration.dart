import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../utils/internal_logger.dart';

Integration<SentryFlutterOptions> createSdkIntegration(
  SentryNativeBinding native,
) {
  return NativeSdkIntegration(native);
}

/// Enables Sentry's native SDKs (Android and iOS) with options.
class NativeSdkIntegration implements Integration<SentryFlutterOptions> {
  NativeSdkIntegration(this._native);

  SentryFlutterOptions? _options;
  final SentryNativeBinding _native;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;

    if (!options.autoInitializeNativeSdk) {
      return;
    }

    try {
      await _native.init(hub);
      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (exception, stackTrace) {
      internalLogger.fatal(
        'nativeSdkIntegration failed to be installed',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options?.automatedTestMode ?? false) {
        rethrow;
      }
    }
  }

  @override
  Future<void> close() async {
    if (_options?.autoInitializeNativeSdk == true) {
      try {
        await _native.close();
      } catch (exception, stackTrace) {
        internalLogger.fatal(
          'nativeSdkIntegration failed to be closed',
          error: exception,
          stackTrace: stackTrace,
        );
        if (_options?.automatedTestMode ?? false) {
          rethrow;
        }
      }
    }
  }
}
