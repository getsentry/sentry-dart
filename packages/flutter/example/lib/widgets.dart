import 'package:flutter/material.dart';

class TooltipButton extends StatelessWidget {
  final String text;
  final String buttonTitle;
  final void Function()? onPressed;

  const TooltipButton({
    required this.onPressed,
    required this.buttonTitle,
    required this.text,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: ElevatedButton(
        onPressed: onPressed,
        key: key,
        child: Text(buttonTitle),
      ),
    );
  }
}
