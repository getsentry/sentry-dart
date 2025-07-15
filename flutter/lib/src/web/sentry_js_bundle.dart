import 'package:meta/meta.dart';
import 'sentry_js_sdk_version.dart';

// The JS SDK version is injected by CI via `update-js.sh`.
@internal
const jsSdkVersion = sentryJsSdkVersion;

// The URLs from which the script should be downloaded.
@internal
const productionScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.min.js',
    'integrity': productionIntegrity,
  }
];

@internal
const debugScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.js',
    'integrity': debugIntegrity,
  },
];
