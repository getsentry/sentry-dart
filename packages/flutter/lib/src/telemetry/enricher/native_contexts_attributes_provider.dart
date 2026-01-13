// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:async';

import 'package:sentry/src/telemetry/enricher/attributes_provider.dart';

import '../../../sentry_flutter.dart';
import '../../integrations/integrations.dart';
import '../../native/sentry_native_binding.dart';

class NativeContextsTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  final SentryNativeBinding _nativeBinding;

  NativeContextsTelemetryAttributesProvider(this._nativeBinding);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes() async {
    final infos = await _nativeBinding.loadContexts() ?? {};

    final contextsMap = infos['contexts'] as Map?;
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

    return attributes;
  }
}
