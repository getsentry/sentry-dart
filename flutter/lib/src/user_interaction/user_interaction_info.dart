import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class UserInteractionInfo {
  final Element element;
  final String description;
  final String type;
  final String eventType;

  const UserInteractionInfo({
    required this.element,
    required this.description,
    required this.type,
    required this.eventType,
  });
}
