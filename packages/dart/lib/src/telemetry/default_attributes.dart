import '../../sentry.dart';
import '../utils/os_utils.dart';

final _operatingSystem = getSentryOperatingSystem();

Map<String, SentryAttribute> defaultAttributes(
    SentryOptions options, Scope scope) {
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

  if (options.sendDefaultPii) {
    final user = scope.user;
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
