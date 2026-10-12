// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/src/isolate/isolate_helper.dart';

class RootIsolateHelper extends IsolateHelper {
  @override
  bool isRootIsolate() => true;
}
