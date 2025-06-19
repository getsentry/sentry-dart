import 'package:meta/meta.dart';

// todo: set up ci to update this and the integrity
@internal
const jsSdkVersion = '9.5.0';

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
