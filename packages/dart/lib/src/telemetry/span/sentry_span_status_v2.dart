enum SentrySpanStatusV2 {
  error('error'),
  ok('ok');

  final String value;
  const SentrySpanStatusV2(this.value);
}
