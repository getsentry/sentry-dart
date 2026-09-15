import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app_config.dart';

class ManualReplayScreen extends StatefulWidget {
  const ManualReplayScreen({super.key, this.replay});

  final SentryReplay? replay;

  @override
  State<ManualReplayScreen> createState() => _ManualReplayScreenState();
}

class _ManualReplayScreenState extends State<ManualReplayScreen> {
  final _activity = <String>[];
  bool _busy = false;
  bool _canLeave = false;
  String? _scenario;
  int _counter = 0;

  SentryReplay get _replay => widget.replay ?? SentryFlutter.replay;

  Future<bool> _run(String label, Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() {
          _activity.insert(0, '$label completed');
          if (_activity.length > 12) _activity.removeLast();
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _activity.insert(0, 'Call failed: $label ($error)');
          if (_activity.length > 12) _activity.removeLast();
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(String scenario, {bool buffering = false}) async {
    await _run(buffering ? 'stop → startBuffering' : 'stop → start', () async {
      await _replay.stop();
      if (buffering) {
        await _replay.startBuffering();
      } else {
        await _replay.start();
      }
      if (mounted) setState(() => _scenario = scenario);
    });
  }

  Future<void> _leave() async {
    if (!await _run('stop on exit', _replay.stop) || !mounted) return;
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canLeave,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Manual Replay'),
        leading: BackButton(onPressed: _busy ? null : _leave),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _run('stop', _replay.stop),
            child: const Text('Stop'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            manualReplay
                ? 'Manual-only demo: automatic replay sampling is off.'
                : 'Automatic sampling is on. Relaunch with '
                      '--dart-define=MANUAL_REPLAY=true for a manual-only demo.',
          ),
          const SizedBox(height: 12),
          const Text('Choose a scenario. Switching stops the previous replay.'),
          FilledButton(
            onPressed: _busy ? null : () => _start('Opt-in recording'),
            child: const Text('Opt-in recording'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _start('Sensitive interaction'),
            child: const Text('Sensitive interaction'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _start('Send recent activity', buffering: true),
            child: const Text('Send recent activity'),
          ),
          if (_scenario != null) ...[
            const Divider(),
            Text(_scenario!, style: Theme.of(context).textTheme.titleLarge),
            if (_scenario == 'Opt-in recording')
              const Text(
                'Starting represents user consent. Interact below, then stop recording.',
              ),
            if (_scenario == 'Sensitive interaction') ...[
              const Text(
                'Pause before entering dummy text, then resume. '
                'Pausing complements privacy masking; never enter a real secret.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run('pause', _replay.pause),
                    child: const Text('Pause'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run('resume', _replay.resume),
                    child: const Text('Resume'),
                  ),
                ],
              ),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Dummy secret only'),
              ),
            ],
            if (_scenario == 'Send recent activity') ...[
              const Text(
                'Interact for a few seconds, then send the recent buffer. '
                'Flush continues recording in session mode; use Stop when finished.',
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('flush', _replay.flush),
                child: const Text('Send replay'),
              ),
            ],
            const SizedBox(height: 12),
            Text('Sample interactions: $_counter'),
            OutlinedButton(
              onPressed: () => setState(() => _counter++),
              child: const Text('Add an interaction'),
            ),
          ],
          const Divider(),
          const Text(
            'API activity (completion does not confirm native recording or upload):',
          ),
          if (_busy) const LinearProgressIndicator(),
          for (final entry in _activity) Text(entry),
        ],
      ),
    ),
  );
}
