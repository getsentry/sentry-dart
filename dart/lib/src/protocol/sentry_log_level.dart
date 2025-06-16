enum SentryLogLevel {
  trace('trace'),
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error'),
  fatal('fatal');

  final String value;
  const SentryLogLevel(this.value);

  int toSeverityNumber() {
    switch (this) {
      case SentryLogLevel.trace:
        return 1;
      case SentryLogLevel.debug:
        return 5;
      case SentryLogLevel.info:
        return 9;
      case SentryLogLevel.warn:
        return 13;
      case SentryLogLevel.error:
        return 17;
      case SentryLogLevel.fatal:
        return 21;
    }
  }
}
