import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/os_utils.dart';

/// Provider for common telemetry attributes available from SDK configuration.
///
/// Computes attributes from [SentryOptions] and [Scope] including SDK info,
/// environment, release, user data (when [SentryOptions.sendDefaultPii] is enabled),
/// and operating system details.
///
/// These attributes are static or semi-static data that can change at runtime
/// (e.g., user attributes). Consider using [cachedByKey] with a cache key based
/// on volatile fields when registering this provider.
@internal
class CommonTelemetryAttributesProvider implements TelemetryAttributesProvider {
  final SentryOptions _options;
  final Scope _scope;

  late final operatingSystem = getSentryOperatingSystem();

  CommonTelemetryAttributesProvider(this._scope, this._options);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(_) {
    final attributes = <String, SentryAttribute>{};
    attributes[SemanticAttributesConstants.sentrySdkName] =
        SentryAttribute.string(_options.sdk.name);

    attributes[SemanticAttributesConstants.sentrySdkVersion] =
        SentryAttribute.string(_options.sdk.version);

    if (_options.environment != null) {
      attributes[SemanticAttributesConstants.sentryEnvironment] =
          SentryAttribute.string(_options.environment!);
    }

    if (_options.release != null) {
      attributes[SemanticAttributesConstants.sentryRelease] =
          SentryAttribute.string(_options.release!);
    }

    if (_options.sendDefaultPii) {
      final user = _scope.user;
      if (user != null) {
        if (user.id != null) {
          attributes[SemanticAttributesConstants.userId] =
              SentryAttribute.string(user.id!);
        }
        if (user.name != null) {
          attributes[SemanticAttributesConstants.userUsername] =
              SentryAttribute.string(user.name!);
        }
        if (user.email != null) {
          attributes[SemanticAttributesConstants.userEmail] =
              SentryAttribute.string(user.email!);
        }
      }
    }

    if (operatingSystem.name != null) {
      attributes[SemanticAttributesConstants.osName] =
          SentryAttribute.string(operatingSystem.name!);
    }

    if (operatingSystem.version != null) {
      attributes[SemanticAttributesConstants.osVersion] =
          SentryAttribute.string(operatingSystem.version!);
    }

    return attributes;
  }
}
