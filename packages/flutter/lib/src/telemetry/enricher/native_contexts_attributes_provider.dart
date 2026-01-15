// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../integrations/integrations.dart';
import '../../native/sentry_native_binding.dart';

/// Provides context information from the native layer.
///
/// Fetches operating system details (name, version) and device information
/// (brand, model, family) from the native SDK.
///
/// Attributes are cached after the first call since native context rarely
/// changes during app lifetime.
@internal
class NativeContextsTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  final SentryNativeBinding _nativeBinding;
  Map<String, SentryAttribute>? _cachedAttributes;

  NativeContextsTelemetryAttributesProvider(this._nativeBinding);

  @override
  Future<Map<String, SentryAttribute>> attributes(Object item,
      {Scope? scope}) async {
    if (_cachedAttributes != null) {
      return _cachedAttributes!;
    }

    final nativeContexts = await _nativeBinding.loadContexts() ?? {};

    final contextsMap = nativeContexts['contexts'] as Map?;
    final contexts = Contexts();
    mergeNativeWithLocalContexts(contextsMap, contexts);

    final attributes = <String, SentryAttribute>{};
    if (contexts.operatingSystem?.name != null) {
      attributes[SemanticAttributesConstants.osName] =
          SentryAttribute.string(contexts.operatingSystem!.name!);
    }
    if (contexts.operatingSystem?.version != null) {
      attributes[SemanticAttributesConstants.osVersion] =
          SentryAttribute.string(contexts.operatingSystem!.version!);
    }
    if (contexts.device?.brand != null) {
      attributes[SemanticAttributesConstants.deviceBrand] =
          SentryAttribute.string(contexts.device!.brand!);
    }
    if (contexts.device?.model != null) {
      attributes[SemanticAttributesConstants.deviceModel] =
          SentryAttribute.string(contexts.device!.model!);
    }
    if (contexts.device?.family != null) {
      attributes[SemanticAttributesConstants.deviceFamily] =
          SentryAttribute.string(contexts.device!.family!);
    }

    _cachedAttributes = attributes;

    return attributes;
  }
}
