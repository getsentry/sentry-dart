import 'package:meta/meta.dart';

import 'sentry_options.dart';

/// This method reads available environment variables and uses them
/// accordingly.
/// To see which environment variables are available, see [EnvironmentVariables]
///
/// The precendence of these options are tricky,
/// see https://docs.sentry.io/platforms/dart/configuration/options/
/// and https://github.com/getsentry/sentry-dart/issues/306
@internal
void setEnvironmentVariables(SentryOptions options, EnvironmentVariables vars) {
  // options has precendence over vars
  options.dsn = options.dsn ?? vars.dsn;

  var environment = options.platformChecker.environment;
  options.environment = options.environment ?? environment;

  // vars has precedence over options
  options.environment = vars.environment ?? options.environment;

  // vars has precedence over options
  options.release = vars.release ?? options.release;
  options.dist = vars.dist ?? options.dist;
}

/// Reads environment variables from the system.
/// In an Flutter environment these can be set via
/// `flutter build --dart-define=VARIABLE_NAME=VARIABLE_VALUE`.
class EnvironmentVariables {
  /// `SENTRY_ENVIRONMENT`
  /// See [SentryOptions.environment]
  String? get environment => _readString('SENTRY_ENVIRONMENT');

  /// `SENTRY_DSN`
  /// See [SentryOptions.dsn]
  String? get dsn => _readString('SENTRY_DSN');

  // `SENTRY_RELEASE`
  /// See [SentryOptions.release]
  String? get release => _readString('SENTRY_RELEASE');

  /// `SENTRY_DIST`
  /// See [SentryOptions.dist]
  String? get dist => _readString('SENTRY_DIST');

  String? _readString(String key) =>
      bool.fromEnvironment(key, defaultValue: false)
          ? String.fromEnvironment(key)
          : null;
}
