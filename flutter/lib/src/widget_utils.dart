import 'package:flutter/widgets.dart';

extension WidgetExtension on Key {
  String? toStringValue() {
    final key = this;
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
