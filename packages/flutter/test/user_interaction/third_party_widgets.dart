import 'package:flutter/widgets.dart';

abstract class ButtonStyleButton extends StatelessWidget {
  const ButtonStyleButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onPressed, child: child);
}

class ElevatedButton extends ButtonStyleButton {
  const ElevatedButton({
    super.key,
    required super.onPressed,
    required super.child,
  });
}
