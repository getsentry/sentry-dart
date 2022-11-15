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
      return 'ValueKey with value "${key.value}"';
    } else if (key is LabeledGlobalKey) {
      return 'LabeledGlobalKey: "${key.toString()}"';
    }

    return 'Key: $key';
  }
}
