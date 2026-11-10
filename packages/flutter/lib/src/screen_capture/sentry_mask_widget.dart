import 'package:flutter/material.dart';

/// Wrapping your widget in [SentryMask] will mask it when capturing replays.
class SentryMask extends StatelessWidget {
  final Widget child;

  const SentryMask(this.child, {super.key});

  @override
  Widget build(BuildContext context) => child;
}
