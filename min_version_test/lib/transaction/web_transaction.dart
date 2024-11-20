import 'package:logging/logging.dart';
import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_dio/sentry_dio.dart';

import 'transaction.dart';

class WebTransaction implements Transaction {
  @override
  Future<void> start() async {
    final transaction = Sentry.startTransaction(
      'incrementCounter',
      'task',
      bindToScope: true,
    );

    final dio = Dio();
    dio.addSentry();
    final log = Logger('_MyHomePageState');

    try {
      final response = await dio.get<String>('https://flutter.dev/');
      print(response);

      await transaction.finish(status: SpanStatus.ok());
    } catch (exception, stackTrace) {
      log.info(exception.toString(), exception, stackTrace);
      await transaction.finish(status: SpanStatus.internalError());
    }
  }
}

Transaction getTransaction() => WebTransaction();
