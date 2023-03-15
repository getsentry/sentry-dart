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
}
