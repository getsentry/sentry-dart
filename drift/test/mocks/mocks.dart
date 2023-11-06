import 'package:drift/drift.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_drift/sentry_drift.dart';

import '../test_database.dart';

@GenerateMocks([
  Hub,
  InsertStatement,
  Insertable,
  LazyDatabase,
  TransactionExecutor,
])
void main() {}