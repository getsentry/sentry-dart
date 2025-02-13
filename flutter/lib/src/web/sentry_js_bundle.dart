import 'package:meta/meta.dart';

// todo: set up ci to update this and the integrity
@internal
const jsSdkVersion = '9.1.0';

// The URLs from which the script should be downloaded.
@internal
const productionScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.min.js',
    'integrity':
        'sha384-MCeGoX8VPkitB3OcF9YprViry6xHPhBleDzXdwCqUvHJdrf7g0DjOGvrhIzpsyKp'
  }
];

@internal
const debugScripts = [
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.js',
    'integrity':
        'sha384-LRAuQWLW6ApqgsRYGfKXlxcs3ylFmeUJsGnVVXxfZgRHNelPjw1712hNEHNuUoVO'
  },
];
