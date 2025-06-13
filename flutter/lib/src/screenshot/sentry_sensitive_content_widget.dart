import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Wrapping your widget in [SensitiveContent] will mark it as containing
/// sensitive content when capturing replays. This is used for backward
/// compatibility with older masking configurations.
@experimental
class SensitiveContent extends StatelessWidget {
  final Widget child;

  const SensitiveContent(this.child, {super.key});

  @override
  Widget build(BuildContext context) => child;
} 