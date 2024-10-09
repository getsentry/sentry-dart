import 'package:flutter/material.dart';

/// Wrapping your widget in [SentryUnmask] will unmask it when capturing replays.
class SentryUnmask extends StatelessWidget {
  final Widget child;

  const SentryUnmask(this.child, {super.key});

  @override
  Widget build(BuildContext context) => child;
}
