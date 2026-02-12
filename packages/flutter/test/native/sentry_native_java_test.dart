@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'sentry_native_java_test_web.dart'
    if (dart.library.io) 'sentry_native_java_test_real.dart' as actual;

void main() => actual.main();
