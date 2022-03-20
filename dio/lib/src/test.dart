import 'package:dio/dio.dart';

import '../sentry_dio.dart';

void main() {
  final dio = Dio();

  dio.addSentry(captureFailedRequests: true);
}
