import 'dart:convert';
import 'dart:math';

import 'package:feedback/feedback.dart' as feedback;
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _defaultHangSeconds = 5;

  final _hangSecondsController =
      TextEditingController(text: '$_defaultHangSeconds');

  int get _hangSeconds {
    final seconds = int.tryParse(_hangSecondsController.text);
    return max(1, seconds ?? _defaultHangSeconds);
  }

  void _hangMainIsolate() {
    final duration = Duration(seconds: _hangSeconds);
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < duration) {
      // Intentionally block the main isolate to test app-hang reporting.
    }
  }

  @override
  void dispose() {
    _hangSecondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
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
                    onPressed: () {
                      // ignore: avoid_print
                      print('A print breadcrumb');
                      Sentry.captureMessage(
                          'A message with a print() Breadcrumb');
                    },
                    text:
                        'Sends a captureMessage to Sentry with a breadcrumb created by a print() statement.',
                    buttonTitle: 'Record print() as breadcrumb',
                  ),
                  TooltipButton(
                    onPressed: () {
                      Sentry.captureMessage(
                        'This event has an extra tag',
                        withScope: (scope) {
                          scope.setTag('foo', 'bar');
                        },
                      );
                    },
                    text:
                        'Sends the capture message event with additional Tag to Sentry.',
                    buttonTitle:
                        'Capture message with scope with additional tag',
                  ),
                  TooltipButton(
                    onPressed: () {
                      Sentry.captureMessage(
                        'This message has an attachment',
                        withScope: (scope) {
                          const txt = 'Lorem Ipsum dolor sit amet';
                          scope.addAttachment(
                            SentryAttachment.fromIntList(
                              utf8.encode(txt),
                              'foobar.txt',
                              contentType: 'text/plain',
                            ),
                          );
                        },
                      );
                    },
                    text:
                        'Sends the capture message with an attachment to Sentry.',
                    buttonTitle: 'Capture message with attachment',
                  ),
                  TooltipButton(
                    onPressed: () {
                      feedback.BetterFeedback.of(context).show(
                        (feedback.UserFeedback userFeedback) {
                          Sentry.captureMessage(
                            userFeedback.text,
                            withScope: (scope) {
                              final entries = userFeedback.extra?.entries;
                              if (entries != null) {
                                for (final extra in entries) {
                                  // ignore: deprecated_member_use
                                  scope.setExtra(extra.key, extra.value);
                                }
                              }
                              scope.addAttachment(
                                SentryAttachment.fromUint8List(
                                  userFeedback.screenshot,
                                  'feedback.png',
                                  contentType: 'image/png',
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    text:
                        'Sends the capture message with an image attachment to Sentry.',
                    buttonTitle: 'Capture message with image attachment',
                  ),
                  TooltipButton(
                    onPressed: () async {
                      final id = await Sentry.captureMessage('UserFeedback');
                      if (!context.mounted) return;
                      SentryFeedbackForm.show(
                        context,
                        associatedEventId: id,
                      );
                    },
                    text:
                        'Shows a custom feedback dialog without an ongoing event that captures and sends user feedback data to Sentry.',
                    buttonTitle: 'Capture Feedback',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hangSecondsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ANR / App Hang duration (seconds)',
                          ),
                        ),
                      ),
                      TooltipButton(
                        onPressed: _hangMainIsolate,
                        text:
                            'Blocks the main isolate for the given duration to trigger an app-hang event.',
                        buttonTitle: 'Trigger ANR / App Hang',
                      ),
                    ],
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
