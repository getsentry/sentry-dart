import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://9934c532bf8446ef961450973c898537@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0; // needed for Dio `networkTracing` feature
      options.debug = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final dio = Dio();
  dio.addSentry(
    maxRequestBodySize: MaxRequestBodySize.small,
    captureFailedRequests: true,
  );

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
