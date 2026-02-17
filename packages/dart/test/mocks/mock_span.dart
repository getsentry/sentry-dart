import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';

class MockSpan extends Mock implements SentrySpan {
  final SentrySpanContext _context = SentrySpanContext(operation: 'test');
  @override
  SentrySpanContext get context => _context;
}
