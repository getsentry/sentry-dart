import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';

import 'FileSystemTransport.dart';
import 'default_integrations.dart';
import 'version.dart';

mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    OptionsConfiguration optionsConfiguration,
    Function callback,
  ) async {
    await Sentry.init((options) async {
      await _initDefaultValues(options, callback);

      await optionsConfiguration(options);
    });
  }

  static Future<void> _initDefaultValues(
      SentryOptions options, Function callback) async {
    // it is necessary to initialize Flutter method channels so that
    // our plugin can call into the native code.
    WidgetsFlutterBinding.ensureInitialized();

    // options.debug = kDebugMode;
    options.debug = true;

    // web still uses a http transport for Web which is set by default
    if (!kIsWeb) {
      options.transport = FileSystemTransport(_channel, options);
    }

    if (!kReleaseMode) {
      options.environment = 'debug';
    }

    await _setReleaseAndDist(options);

    // TODO: load debug images when split symbols are enabled.

    _addDefaultIntegrations(options, callback);

    _setSdk(options);
  }

  static Future<void> _setReleaseAndDist(SentryOptions options) async {
    if (!kIsWeb) {
      final packageInfo = await PackageInfo.fromPlatform();

      final release =
          '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
      options.logger(SentryLevel.debug, 'release: $release');

      options.release = release;
      options.dist = packageInfo.buildNumber;
    } else {
      // TODO: web release
    }
  }

  static void _addDefaultIntegrations(
    SentryOptions options,
    Function callback,
  ) {
    // Throws when running on the browser
    if (!kIsWeb) {
      options.addIntegration(isolateErrorIntegration);
    }
    options.addIntegration(flutterErrorIntegration);
    options.addIntegration(nativeSdkIntegration(options, _channel));
    options.addIntegration(deviceInfosIntegration(options, _channel));
    options.addIntegration(runZonedGuardedIntegration(callback));
  }

  static void _setSdk(SentryOptions options) {
    // overwrite sdk info with current flutter sdk
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: List.from(options.sdk.integrations),
      packages: List.from(options.sdk.packages),
    );
    sdk.addPackage('pub:sentry_flutter', sdkVersion);
    options.sdk = sdk;
  }
}
