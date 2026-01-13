import 'dart:async';

import 'package:sentry/sentry.dart';

import '../../native/sentry_native_binding.dart';
import 'native_contexts_attributes_provider.dart';

class FlutterTelemetryEnricherIntegration extends Integration {
  final SentryNativeBinding _nativeBinding;

  FlutterTelemetryEnricherIntegration(this._nativeBinding);

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    final nativeContextsAttributeProvider =
        NativeContextsAttributesProvider(_nativeBinding);
    options.telemetryEnricher
        .registerSpanAttributesProvider(nativeContextsAttributeProvider);
    options.telemetryEnricher
        .registerLogAttributesProvider(nativeContextsAttributeProvider);
  }
}
