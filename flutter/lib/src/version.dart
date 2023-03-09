/// The SDK version reported to Sentry.io in the submitted events.
const String sdkVersion = '7.0.0-rc.2';

/// The default SDK name reported to Sentry.io in the submitted events.
String sdkName(bool isWeb) => isWeb ? _browserSdkName : _ioSdkName;

/// The default SDK name reported to Sentry.io in the submitted events.
const String _ioSdkName = 'sentry.dart.flutter';

/// The default SDK name reported to Sentry.io in the submitted events.
const String _browserSdkName = '$_ioSdkName.browser';
