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
  static const _sentryEnvironment = 'SENTRY_ENVIRONMENT';
  static const _sentryDsn = 'SENTRY_DSN';
  static const _sentryRelease = 'SENTRY_RELEASE';
  static const _sentryDist = 'SENTRY_DSN';

  /// `SENTRY_ENVIRONMENT`
  /// See [SentryOptions.environment]
  String? get environment => const bool.hasEnvironment(_sentryEnvironment)
      ? const String.fromEnvironment(_sentryEnvironment)
      : null;

  /// `SENTRY_DSN`
  /// See [SentryOptions.dsn]
  String? get dsn => const bool.hasEnvironment(_sentryDsn)
      ? const String.fromEnvironment(_sentryDsn)
      : null;

  // `SENTRY_RELEASE`
  /// See [SentryOptions.release]
  String? get release => const bool.hasEnvironment(_sentryRelease)
      ? const String.fromEnvironment(_sentryRelease)
      : null;

  /// `SENTRY_DIST`
  /// See [SentryOptions.dist]
  String? get dist => const bool.hasEnvironment(_sentryDist)
      ? const String.fromEnvironment(_sentryDist)
      : null;
}
