enum SentrySpanStatusV2 {
  error('error'),
  cancelled('cancelled'),
  deadlineExceeded('deadline_exceeded'),
  ok('ok');

  final String value;
  const SentrySpanStatusV2(this.value);
}
