import 'package:meta/meta.dart';

// todo: set up ci to update this and the integrity
@internal
const jsSdkVersion = '8.42.0';

// The URLs from which the script should be downloaded.
@internal
const productionScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.min.js',
    'integrity':
        'sha384-bG2vyJAuRm/JbGQrlET5H7y0CTvPF0atiBjekU/WUKUwKwThDXrqRhZiQ+jWaagS'
  }
];

@internal
const debugScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.js',
    'integrity':
        'sha384-WybdMW5lxuTpznT+4dobKr9wWgFoISsinHnIXDF8HBrG5/yGrmEhHRyMS1kfLsMi'
  },
];
