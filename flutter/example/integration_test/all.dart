// Workaround for https://github.com/flutter/flutter/issues/101031
import 'integration_test.dart' as a;
import 'profiling_test.dart' as b;
import 'replay_test.dart' as c;

void main() {
  a.main();
  b.main();
  c.main();
}
