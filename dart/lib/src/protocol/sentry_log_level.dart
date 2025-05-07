enum SentryLogLevel {
  trace('trace'),
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error'),
  fatal('fatal');

  final String value;
  const SentryLogLevel(this.value);
}
