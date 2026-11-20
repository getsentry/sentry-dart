// Imported conditionally: `dart:ffi` doesn't compile for the web, and
// @TestOn doesn't stop the import from being compiled.
@TestOn('vm && windows')
@Tags(['native-backend'])
library;

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'sentry_native_test_web.dart'
    if (dart.library.io) 'sentry_native_stack_guarantee_test_ffi.dart'
    as actual;

void main() => actual.main();
