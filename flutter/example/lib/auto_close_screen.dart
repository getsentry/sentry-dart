import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

/// This screen is only used to demonstrate how route navigation works.
/// Init will create a child span and pop the screen after 3 seconds.
/// Afterwards the transaction should be seen on the performance page.
class AutoCloseScreen extends StatefulWidget {
  const AutoCloseScreen({super.key});

  @override
  _AutoCloseScreenState createState() => _AutoCloseScreenState();
}

class _AutoCloseScreenState extends State<AutoCloseScreen> {
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
