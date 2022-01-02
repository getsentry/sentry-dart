import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
    },
    appRunner: initDio, // Init your App.
  );
}

void initDio() {
  final dio = Dio();
  dio.httpClientAdapter = SentryHttpClientAdapter();
}
