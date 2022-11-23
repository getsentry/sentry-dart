import 'package:flutter/widgets.dart';

class UserInteractionWidget {
  final Element element;
  final String description;
  final String type;
  final String eventType;

  const UserInteractionWidget({
    required this.element,
    required this.description,
    required this.type,
    required this.eventType,
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
    }
    return key.toString();
  }
}
