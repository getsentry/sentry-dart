// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../widgets.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metrics')),
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
                      Sentry.metrics.count(
                        'screen.view',
                        1,
                        attributes: {
                          'screen': SentryAttribute.string('HomeScreen'),
                          'source': SentryAttribute.string('navigation'),
                        },
                      );
                      Sentry.metrics.gauge(
                        'app.memory_usage',
                        128,
                        unit: 'megabyte',
                        attributes: {
                          'state': SentryAttribute.string('foreground'),
                        },
                      );
                      Sentry.metrics.distribution(
                        'ui.render_time',
                        16.7,
                        unit: 'millisecond',
                        attributes: {
                          'widget': SentryAttribute.string('ListView'),
                          'item_count': SentryAttribute.int(50),
                        },
                      );
                    },
                    text: 'Demonstrates Sentry Metrics.',
                    buttonTitle: 'Send Metrics',
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
