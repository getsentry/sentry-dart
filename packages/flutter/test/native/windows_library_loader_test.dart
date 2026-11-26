// Imported conditionally: `dart:ffi` doesn't compile for the web, and
// @TestOn doesn't stop the import from being compiled.
@TestOn('vm && windows')
library;

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'c/sentry_native_test_web.dart'
    if (dart.library.io) 'windows_library_loader_test_ffi.dart'
    as actual;

void main() => actual.main();
