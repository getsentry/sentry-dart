// todo: set up ci to update this and the integrity
import 'package:meta/meta.dart';

@internal
const jsSdkVersion = '8.37.1';

@internal
const productionScripts = [
  {
    'url':
        'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.replay.min.js',
    'integrity':
        'sha384-IZS0kTfvAku3LBcvcHWThKT6lKBimvLUVNZgqF/jtmVAw99L25MM+RhAnozr6iVY'
  },
  {
    // todo: might need to be adjusted based on renderer (canvas vs html) later on
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/replay-canvas.min.js',
    'integrity':
        'sha384-UNUCiMVh5gTr9Z45bRUPU5eOHHKGOI80UV3zM858k7yV/c6NNhtSJnIDjh+jJ8Vk'
  },
];

@internal
const debugScripts = [
  {
    'url':
        'https://browser.sentry-cdn.com/$jsSdkVersion/bundle.tracing.replay.js',
  },
  {
    'url': 'https://browser.sentry-cdn.com/$jsSdkVersion/replay-canvas.js',
  },
];
