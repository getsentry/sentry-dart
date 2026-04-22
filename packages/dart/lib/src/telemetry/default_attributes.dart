import 'package:meta/meta.dart';

import '../../sentry.dart';

/// Attribute keys attached to lightweight telemetry signals
/// (logs, metrics, and non-segment spans) by the enricher.
///
/// Kept intentionally small due to size concerns. Other attribute layers
/// (sdk, environment, release, user) are provided by [defaultAttributes].
/// Segment spans use the full projection from [Contexts.toAttributes] instead.
@internal
const Set<String> minimalContextAttributes = {
  SemanticAttributesConstants.deviceBrand,
  SemanticAttributesConstants.deviceModel,
  SemanticAttributesConstants.deviceFamily,
  SemanticAttributesConstants.osName,
  SemanticAttributesConstants.osVersion,
  SemanticAttributesConstants.osBuildId,
  SemanticAttributesConstants.osKernelVersion,
  SemanticAttributesConstants.osRooted,
  SemanticAttributesConstants.osRawDescription,
  SemanticAttributesConstants.osTheme,
};

Map<String, SentryAttribute> defaultAttributes(SentryOptions options,
    {Scope? scope}) {
  final attributes = <String, SentryAttribute>{};

  attributes[SemanticAttributesConstants.sentrySdkName] =
      SentryAttribute.string(options.sdk.name);

  attributes[SemanticAttributesConstants.sentrySdkVersion] =
      SentryAttribute.string(options.sdk.version);

  if (options.environment != null) {
    attributes[SemanticAttributesConstants.sentryEnvironment] =
        SentryAttribute.string(options.environment!);
  }

  if (options.release != null) {
    attributes[SemanticAttributesConstants.sentryRelease] =
        SentryAttribute.string(options.release!);
  }

  final user = scope?.user;
  if (user != null) {
    attributes.addAllIfAbsent(user.toAttributes());
  }

  return attributes;
}
