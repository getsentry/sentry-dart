import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../protocol/sentry_level.dart';

/// Default log output for web. `dart:developer.log` calls do not surface in
/// the browser dev console on Flutter Web, so diagnostic SDK messages were
/// otherwise silently dropped.
///
/// We deliberately forward to `window.console.*` (via `package:web`) instead
/// of using Dart's top-level `print`. Sentry installs a print-zone hook in
/// `runZonedGuarded` to record `print` calls as breadcrumbs, and routing the
/// SDK's own diagnostic output through `print` would feed those internal
/// lines back as user-visible breadcrumbs. Calling `console.*` directly
/// bypasses that hook entirely.
///
/// The SDK's internal logger is also short-circuited by `kDebugMode` in
/// release builds, so this code is tree-shaken from production.
void defaultLogOutput({
  required String name,
  required SentryLevel level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
}) {
  final formatted = '[$name] [${level.name}] $message'.toJS;
  final errorJs = error?.toString().toJS;
  final stackJs = stackTrace?.toString().toJS;

  switch (level) {
    case SentryLevel.fatal:
    case SentryLevel.error:
      web.console.error(formatted);
      if (errorJs != null) web.console.error(errorJs);
      if (stackJs != null) web.console.error(stackJs);
    case SentryLevel.warning:
      web.console.warn(formatted);
      if (errorJs != null) web.console.warn(errorJs);
      if (stackJs != null) web.console.warn(stackJs);
    case SentryLevel.info:
      web.console.info(formatted);
      if (errorJs != null) web.console.info(errorJs);
      if (stackJs != null) web.console.info(stackJs);
    case SentryLevel.debug:
    default:
      web.console.debug(formatted);
      if (errorJs != null) web.console.debug(errorJs);
      if (stackJs != null) web.console.debug(stackJs);
  }
}
