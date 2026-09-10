// Workaround for https://github.com/flutter/flutter/issues/101031
import 'integration_test.dart' as a;
import 'profiling_test.dart' as b;
import 'replay_test.dart' as c;
import 'platform_integrations_test.dart' as d;
import 'native_jni_utils_test.dart' as e;
import 'native_sdk_lifecycle_test.dart' as f;

void main() {
  a.main();
  b.main();
  c.main();
  d.main();
  e.main();
  f.main();
}
