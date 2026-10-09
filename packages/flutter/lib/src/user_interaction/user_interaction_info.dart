import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class UserInteractionInfo {
  final Element element;
  final String type;
  final bool labelFromText;

  const UserInteractionInfo({
    required this.element,
    required this.type,
    required this.labelFromText,
  });
}
