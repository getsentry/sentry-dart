import 'package:flutter/widgets.dart';

class TappedWidget {
  final Element element;
  final String description;
  final String type;

  const TappedWidget({
    required this.element,
    required this.description,
    required this.type,
  });

  String? get keyValue {
    final key = element.widget.key;
    if (key == null) {
      return null;
    }
    if (key is ValueKey<String>) {
      return key.value;
    } else if (key is ValueKey) {
      return key.value?.toString();
    } // else if (key is LabeledGlobalKey) {
    //   return key.toString();
    // }
    return key.toString();
  }
}
