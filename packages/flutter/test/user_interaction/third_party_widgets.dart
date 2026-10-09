import 'package:flutter/widgets.dart';

abstract class ButtonStyleButton extends StatelessWidget {
  const ButtonStyleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(onTap: onPressed, child: child);
    final tooltip = this.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class ElevatedButton extends ButtonStyleButton {
  const ElevatedButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.tooltip,
  });
}

class InkWell extends StatelessWidget {
  const InkWell({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: child);
}

class Tooltip extends StatelessWidget {
  const Tooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
