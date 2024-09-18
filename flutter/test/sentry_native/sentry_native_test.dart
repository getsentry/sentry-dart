// We must conditionally import the actual test code, otherwise tests fail on
// a browser. @TestOn('vm') doesn't help by itself in this case because imports
// are still evaluated, thus causing a compilation failure.
@TestOn('vm && windows')
library sentry_native_test;

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'sentry_native_test_web.dart'
    if (dart.library.io) 'sentry_native_test_ffi.dart' as actual;

// Defining main() here allows us to manually run/debug from VSCode.
// If we didn't need that, we could just `export` above.
void main() => actual.main();
