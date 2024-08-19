import 'package:js/js.dart';
import 'package:meta/meta.dart';

@internal
@JS('Sentry')
class SentryJsBridge {
  external static void init(dynamic options);

  external static void close();

  external static dynamic captureException(dynamic exception);

  external static dynamic captureMessage(String message);

  external static dynamic captureEvent(dynamic event);

  external static dynamic replayIntegration(dynamic configuration);

  external static dynamic replayCanvasIntegration();

  external static SentryJsClient getClient();
}

@JS('Client')
@staticInterop
class SentryJsClient {}

extension SentryJsClientExtension on SentryJsClient {
  external dynamic sendEnvelope(dynamic envelope);
}
