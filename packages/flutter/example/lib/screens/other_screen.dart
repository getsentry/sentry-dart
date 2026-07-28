// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../widgets.dart';

class OtherScreen extends StatelessWidget {
  const OtherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Other')),
      body: SingleChildScrollView(
        child: Center(
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  TooltipButton(
                    onPressed: () =>
                        SecondaryScaffold.openSecondaryScaffold(context),
                    text:
                        'Demonstrates how the router integration adds a navigation event to the breadcrumbs that can be seen when throwing an exception for example.',
                    buttonTitle: 'Open another Scaffold',
                  ),
                  TooltipButton(
                    onPressed: () {
                      Sentry.addFeatureFlag('feature-one', true);
                    },
                    text: 'Demonstrates the feature flags.',
                    buttonTitle: 'Add "feature-one" flag',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryScaffold extends StatelessWidget {
  const SecondaryScaffold({super.key});

  static Future<void> openSecondaryScaffold(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings:
            const RouteSettings(name: 'SecondaryScaffold', arguments: 'foobar'),
        builder: (context) => const SecondaryScaffold(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SecondaryScaffold')),
      body: Center(
        child: Column(
          children: [
            const Text(
              'You have added a navigation event '
              'to the crash reports breadcrumbs.',
            ),
            MaterialButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
            MaterialButton(
              onPressed: () {
                throw Exception('Exception from SecondaryScaffold');
              },
              child: const Text('throw uncaught exception'),
            ),
          ],
        ),
      ),
    );
  }
}
