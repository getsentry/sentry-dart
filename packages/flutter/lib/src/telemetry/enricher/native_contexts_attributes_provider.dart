// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../integrations/integrations.dart';
import '../../native/sentry_native_binding.dart';

/// Creates a native contexts attributes provider.
///
/// Fetches context information from the native layer including operating system
/// details (name, version) and device information (brand, model, family).
/// This data is loaded asynchronously from the native SDK.
///
/// Since native context rarely changes during app lifetime, this provider
/// should be wrapped with [cached] when registered.
@internal
class NativeContextsTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  final SentryNativeBinding _nativeBinding;
  Map<String, SentryAttribute>? cachedAttributes;

  NativeContextsTelemetryAttributesProvider(this._nativeBinding);

  @override
  Future<Map<String, SentryAttribute>> attributes(Object item,
      {Scope? scope}) async {
    // The attributes loaded by the native contexts are generally stable
    // and dont need to be re-fetched every time.
    if (cachedAttributes != null) {
      return cachedAttributes!;
    }

    final nativeContexts = await _nativeBinding.loadContexts() ?? {};

    final contextsMap = nativeContexts['contexts'] as Map?;
    final contexts = Contexts();
    mergeNativeWithLocalContexts(contextsMap, contexts);

    final attributes = <String, SentryAttribute>{};
    if (contexts.operatingSystem?.name != null) {
      attributes['os.name'] = SentryAttribute.string(
        contexts.operatingSystem!.name!,
      );
    }
    if (contexts.operatingSystem?.version != null) {
      attributes['os.version'] = SentryAttribute.string(
        contexts.operatingSystem!.version!,
      );
    }
    if (contexts.device?.brand != null) {
      attributes['device.brand'] = SentryAttribute.string(
        contexts.device!.brand!,
      );
    }
    if (contexts.device?.model != null) {
      attributes['device.model'] = SentryAttribute.string(
        contexts.device!.model!,
      );
    }
    if (contexts.device?.family != null) {
      attributes['device.family'] = SentryAttribute.string(
        contexts.device!.family!,
      );
    }

    cachedAttributes = attributes;

    return attributes;
  }
}
