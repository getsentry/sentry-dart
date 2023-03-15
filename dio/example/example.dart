import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate =
          1.0; // needed for Dio `captureFailedRequests` feature
      options.debug = true;
      options.sendDefaultPii = true;

      options.maxRequestBodySize = MaxRequestBodySize.small;
      options.maxResponseBodySize = MaxResponseBodySize.small;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final dio = Dio();
  dio.addSentry();

  final transaction = Sentry.startTransaction(
    'dio-web-request',
    'request',
    bindToScope: true,
  );

  try {
    final response = await dio
        .get<Map<String, Object?>>('https://www.google.com/idontexist');

    print(response.toString());

    transaction.status =
        SpanStatus.fromHttpStatusCode(response.statusCode ?? -1);
  } catch (exception) {
    transaction.throwable = exception;
    transaction.status = const SpanStatus.internalError();
  } finally {
    await transaction.finish();
  }

  await Sentry.close();
}
