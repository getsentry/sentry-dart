import 'dart:async';

import '../../../sentry.dart';
import '../../utils/os_utils.dart';
import 'enricher.dart';

class CommonAttributesProvider implements TelemetryAttributesProvider {
  final SentryOptions _options;
  final Scope _scope;

  late final operatingSystem = getSentryOperatingSystem();

  CommonAttributesProvider(this._scope, this._options);

  @override
  String get name => 'CommonAttributesProvider';

  @override
  FutureOr<Map<String, SentryAttribute>> provide() {
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
