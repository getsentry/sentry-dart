import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ManualReplayScreen extends StatefulWidget {
  const ManualReplayScreen({super.key});

  @override
  State<ManualReplayScreen> createState() => _ManualReplayScreenState();
}

class _ManualReplayScreenState extends State<ManualReplayScreen> {
  late final Future<void> _pause;

  @override
  void initState() {
    super.initState();
    _pause = SentryFlutter.replay.pause();
  }

  @override
  void dispose() {
    unawaited(_resumeReplay());
    super.dispose();
  }

  Future<void> _resumeReplay() async {
    try {
      // Preserve ordering even if the screen is closed before pause completes.
      try {
        await _pause;
      } finally {
        await SentryFlutter.replay.resume();
      }
    } catch (error) {
      debugPrint('Could not restore replay after leaving the screen: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manual Replay')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<void>(
        future: _pause,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Could not pause replay. Go back to try again.');
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This screen pauses Session Replay on entry and resumes it '
                'when you leave. Try entering dummy text, then go back.',
              ),
              SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Dummy secret only'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
