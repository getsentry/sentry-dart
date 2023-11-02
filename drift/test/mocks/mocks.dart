import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';

import '../test_database.dart';

@GenerateMocks([
  Hub,
  AppDatabase,
  TodoItems,
])
void main() {}