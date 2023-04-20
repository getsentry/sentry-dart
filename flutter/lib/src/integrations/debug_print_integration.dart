import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';

/// Integration which intercepts Flutters [debugPrint] method.
/// If this integration is added, all calls to [debugPrint] a redirected to
/// add a [Breadcrumb]. [debugPrint] is not outputting to the console anymore!
/// This integration fixes the issue described in
/// [#492](https://github.com/getsentry/sentry-dart/issues/492).
class DebugPrintIntegration implements Integration<SentryFlutterOptions> {
  DebugPrintCallback? _debugPrintBackup;
  late Hub _hub;
  late SentryFlutterOptions _options;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _hub = hub;
    _options = options;

    final isDebug = options.platformChecker.isDebugMode();
    final enablePrintBreadcrumbs = options.enablePrintBreadcrumbs;
    if (isDebug || !enablePrintBreadcrumbs) {
      return;
    }

    _debugPrintBackup = debugPrint;

    // We're simply replacing debugPrint here. The default implementation is a
    // a throttling system which prints using Darts print method. It's basically
    // a fire and forget method which completes sometime in the future. We can't
    // observe when it's done.
    //
    // This makes it impossible to just disable adding print() breadcrumbs
    // before debugPrint is called and re-enable it after debugPrint was called.
    // See the docs for more information.
    // https://api.flutter.dev/flutter/foundation/debugPrint.html
    debugPrint = _debugPrint;

    options.sdk.addIntegration('debugPrintIntegration');
  }

  @override
  void close() {
    if (_debugPrintBackup != null) {
      debugPrint = _debugPrintBackup!;
    }
  }

  void _debugPrint(String? message, {int? wrapWidth}) {
    if (message == null) {
      _options.logger(
        SentryLevel.debug,
        'debugPrint Integration received "null" as message. '
        'The message is dropped.',
      );
      return;
    }
    _hub.addBreadcrumb(Breadcrumb.console(
      message: message,
      level: SentryLevel.debug,
    ));
  }
}
