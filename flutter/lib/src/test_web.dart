@JS()
library web_sentry_loader;

import 'dart:async';

import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'dart:html';

import '../sentry_flutter.dart';

@JS('Sentry')
class SentryJS {
  external static void init(dynamic options);

  external static dynamic captureException(dynamic exception);

  external static dynamic captureMessage(String message);

  external static dynamic replayIntegration(dynamic configuration);

  external static dynamic replayCanvasIntegration();
}

void loadSentryJS() {
  // if (_sentry != null) return; // Already loaded

  final script = ScriptElement()
    ..src = 'https://browser.sentry-cdn.com/8.24.0/bundle.tracing.replay.min.js'
    ..integrity =
        'sha384-eEn/WSvcP5C2h5g0AGe5LCsheNNlNkn/iV8y5zOylmPoOfSyvZ23HBDnOhoB0sdL'
    ..crossOrigin = 'anonymous';

  document.head!.append(script);

  //   src="https://browser.sentry-cdn.com/8.24.0/replay-canvas.min.js"
  //   integrity="sha384-gSFCG8IdZobb6PWs7SwuaES/R5PPt+gw4y6N/Kkwlic+1Hzf21EUm5Dg/WbYMxTE"
  //   crossorigin="anonymous"

  final script2 = ScriptElement()
    ..src = 'https://browser.sentry-cdn.com/8.24.0/replay-canvas.min.js'
    ..integrity =
        'sha384-gSFCG8IdZobb6PWs7SwuaES/R5PPt+gw4y6N/Kkwlic+1Hzf21EUm5Dg/WbYMxTE'
    ..crossOrigin = 'anonymous';

  document.head!.append(script2);
}

Future<void> initSentryJS(
    FutureOr<void> Function(SentryOptions) configuration) async {
  final options = SentryOptions();
  await configuration(options);

  final jsOptions = js_util.jsify({
    'dsn': options.dsn,
    'debug': true,
    'replaysSessionSampleRate': 1.0,
    'replaysOnErrorSampleRate': 1.0,
    'integrations': [
      SentryJS.replayIntegration(js_util.jsify({
        'maskAllText': false,
        'blockAllMedia': false,
      })),
      SentryJS.replayCanvasIntegration(),
    ],
  });

  SentryJS.init(jsOptions);
}
