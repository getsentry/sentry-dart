import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

class DelayedScreen extends StatefulWidget {
  @override
  _DelayedScreenState createState() => _DelayedScreenState();
}

class _DelayedScreenState extends State<DelayedScreen> {
  static const delayInSeconds = 3;

  @override
  void initState() {
    super.initState();
    _doComplexOperationThenClose();
  }

  Future<void> _doComplexOperationThenClose() async {
    final activeSpan = Sentry.getSpan();
    final childSpan = activeSpan?.startChild('complex operation', description: 'running a $delayInSeconds seconds operation');
    await Future.delayed(const Duration(seconds: delayInSeconds));
    childSpan?.finish();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delayed Screen'),
      ),
      body: const Center(
        child: Text(
          'This screen will automatically close in $delayInSeconds seconds...',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
