@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'android_envelope_sender_test_web.dart'
    if (dart.library.io) 'android_envelope_sender_test_real.dart' as actual;

void main() => actual.main();
