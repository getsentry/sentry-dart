import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/isolate_utils.dart' as isolate_utils;

@internal
class IsolateHelper {
  // ignore: invalid_use_of_internal_member
  String? getIsolateName() => isolate_utils.getIsolateName();

  bool isRootIsolate() {
    return ServicesBinding.rootIsolateToken != null;
  }
}
