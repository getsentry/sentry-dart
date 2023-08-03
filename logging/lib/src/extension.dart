// ignore_for_file: public_member_api_docs

import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

extension LogRecordX on LogRecord {
  Breadcrumb toBreadcrumb() {
    return Breadcrumb(
      category: 'log',
      type: 'debug',
      timestamp: time.toUtc(),
      level: level.toSentryLevel(),
      message: message,
      data: <String, Object>{
        if (object != null) 'LogRecord.object': object!.toString(),
        if (error != null) 'LogRecord.error': error!.toString(),
        if (stackTrace != null) 'LogRecord.stackTrace': stackTrace!.toString(),
        'LogRecord.loggerName': loggerName,
        'LogRecord.sequenceNumber': sequenceNumber,
      },
    );
  }

  SentryEvent toEvent() {
    return SentryEvent(
      timestamp: time.toUtc(),
      logger: loggerName,
      level: level.toSentryLevel(),
      message: SentryMessage(message),
      throwable: error,
      // ignore: deprecated_member_use
      extra: <String, Object>{
        if (object != null) 'LogRecord.object': object!.toString(),
        'LogRecord.sequenceNumber': sequenceNumber,
      },
    );
  }
}

extension LogLevelX on Level {
  SentryLevel? toSentryLevel() {
    return <Level, SentryLevel?>{
      Level.ALL: SentryLevel.debug,
      Level.FINEST: SentryLevel.debug,
      Level.FINER: SentryLevel.debug,
      Level.FINE: SentryLevel.debug,
      Level.CONFIG: SentryLevel.debug,
      Level.INFO: SentryLevel.info,
      Level.WARNING: SentryLevel.warning,
      Level.SEVERE: SentryLevel.error,
      Level.SHOUT: SentryLevel.fatal,
      Level.OFF: null,
    }[this];
  }
}
