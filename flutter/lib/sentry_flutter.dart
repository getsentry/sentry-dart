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

    // TODO: load debug images when split symbols are enabled.

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    _addDefaultIntegrations(options, callback);

    await _setReleaseAndDist(options);

    _setSdk(options);
  }

  static Future<void> _setReleaseAndDist(SentryOptions options) async {
    try {
      if (!kIsWeb) {
        final packageInfo = await PackageInfo.fromPlatform();

        final release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.logger(SentryLevel.debug, 'release: $release');

        options.release = release;
        options.dist = packageInfo.buildNumber;
      } else {
        final String release = await _channel.invokeMethod('platformVersion');
        options.release = release;
      }
    } catch (error) {
      options.logger(
          SentryLevel.error, 'Failed to load release and dist: $error');
    }
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static void _addDefaultIntegrations(
    SentryOptions options,
    Function callback,
  ) {
    // the ordering here matters, as we'd like to first start the native integration
    // that allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (!kIsWeb) {
      options.addIntegration(nativeSdkIntegration(options, _channel));
    }

    // will catch any errors that may occur in the Flutter framework itself.
    options.addIntegration(flutterErrorIntegration);

    // Throws when running on the browser
    if (!kIsWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegration(isolateErrorIntegration);
    }

    // finally the runZonedGuarded, catch any errors in Dart code running
    // ‘outside’ the Flutter framework
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
