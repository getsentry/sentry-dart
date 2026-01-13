import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/os_utils.dart';

/// Provides common attributes for all telemetry items.
///
/// Includes SDK metadata, environment/release, user identity (gated by PII),
/// and operating system information.
@internal
final class CommonTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  late final _operatingSystem = getSentryOperatingSystem();

  @override
  bool supports(Object item) => true;

  @override
  FutureOr<Map<String, SentryAttribute>> call(
      Object _, TelemetryAttributesProviderContext context) {
    final attributes = <String, SentryAttribute>{};

    attributes[SemanticAttributesConstants.sentrySdkName] =
        SentryAttribute.string(context.options.sdk.name);

    attributes[SemanticAttributesConstants.sentrySdkVersion] =
        SentryAttribute.string(context.options.sdk.version);

    if (context.options.environment != null) {
      attributes[SemanticAttributesConstants.sentryEnvironment] =
          SentryAttribute.string(context.options.environment!);
    }

    if (context.options.release != null) {
      attributes[SemanticAttributesConstants.sentryRelease] =
          SentryAttribute.string(context.options.release!);
    }

    if (context.options.sendDefaultPii) {
      final user = context.scope.user;
      if (user != null) {
        if (user.id != null) {
          attributes[SemanticAttributesConstants.userId] =
              SentryAttribute.string(user.id!);
        }
        if (user.name != null) {
          attributes[SemanticAttributesConstants.userName] =
              SentryAttribute.string(user.name!);
        }
        if (user.email != null) {
          attributes[SemanticAttributesConstants.userEmail] =
              SentryAttribute.string(user.email!);
        }
      }
    }

    if (_operatingSystem.name != null) {
      attributes[SemanticAttributesConstants.osName] =
          SentryAttribute.string(_operatingSystem.name!);
    }

    if (_operatingSystem.version != null) {
      attributes[SemanticAttributesConstants.osVersion] =
          SentryAttribute.string(_operatingSystem.version!);
    }

    return attributes;
  }
}
