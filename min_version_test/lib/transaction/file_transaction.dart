import 'package:min_version_test/transaction/transaction.dart';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:dio/dio.dart';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_dio/sentry_dio.dart';

class FileTransaction implements Transaction {
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
      final file = File('response.txt');
      final response = await dio.get<String>('https://flutter.dev/');
      await file.writeAsString(response.data ?? 'no response');

      await transaction.finish(status: SpanStatus.ok());
    } catch (exception, stackTrace) {
      log.info(exception.toString(), exception, stackTrace);
      await transaction.finish(status: SpanStatus.internalError());
    }
  }
}

Transaction getTransaction() => FileTransaction();
