import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class WidgetUtils {
  static String? toStringValue(Key? key) {
    if (key == null) {
      return null;
    }
    if (key is ValueKey<String>) {
      return key.value;
    } else if (key is ValueKey) {
      return key.value?.toString();
    } else if (key is GlobalObjectKey) {
      return key.value.toString();
    } else if (key is ObjectKey) {
      return key.value?.toString();
    }
    return key.toString();
  }
}
