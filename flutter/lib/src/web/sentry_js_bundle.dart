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
    'integrity':
        'sha384-nsiByevQ25GvAyX+c3T3VctX7x10qZpYsLt3dfkBt04A71M451kWQEu+K4r1Uuk3'
  }
];

@internal
const debugScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.js',
    'integrity':
        'sha384-Iw737zuRcOiGNbRmsWBSA17nCEbheKhfoqbG/3/9JScn1+WV/V6KdisyboGHqovH'
  },
];
