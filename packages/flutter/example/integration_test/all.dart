// Workaround for https://github.com/flutter/flutter/issues/101031
import 'integration_test.dart' as a;
import 'replay_test.dart' as b;
import 'platform_integrations_test.dart' as c;
import 'native_jni_utils_test.dart' as d;
import 'native_sdk_lifecycle_test.dart' as e;
import 'replay_config_test.dart' as f;
import 'cocoa_replay_test.dart' as g;
import 'android_replay_network_details_test.dart' as h;
import 'cocoa_ffi_test.dart' as i;

void main() {
  a.main();
  b.main();
  c.main();
  d.main();
  e.main();
  f.main();
  g.main();
  h.main();
  i.main();
}
