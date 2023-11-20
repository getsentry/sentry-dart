import 'package:drift/drift.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';

@GenerateMocks([
  Hub,
  LazyDatabase,
  TransactionExecutor,
])
void main() {}
