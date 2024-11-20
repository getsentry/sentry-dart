import 'package:meta/meta.dart';

// todo: set up ci to update this and the integrity
@internal
const jsSdkVersion = '8.39.0';

@internal
const productionScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.min.js',
    'integrity':
        'sha384-GmCdCRO2s8VuYopAldiuHl/uns+EWDcLodj8AW810pK14r3vPQxoDNsMxnitCt18'
  }
];

@internal
const debugScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.js',
  },
];
