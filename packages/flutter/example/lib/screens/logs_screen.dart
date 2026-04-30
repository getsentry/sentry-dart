// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../widgets.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: SingleChildScrollView(
        child: Center(
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TooltipButton(
                    onPressed: () {
                      final log = Logger('Logging');
                      log.info('My Logging test');
                    },
                    text:
                        'Demonstrates the logging integration. log.info() will create an info event send it to Sentry.',
                    buttonTitle: 'Logging',
                  ),
                  TooltipButton(
                    onPressed: () {
                      Sentry.logger
                          .info('Sentry Log With Test Attribute', attributes: {
                        'test-attribute': SentryAttribute.string('test-value'),
                      });
                    },
                    text: 'Demonstrates the logging with Sentry Log.',
                    buttonTitle: 'Sentry Log with Attribute',
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
