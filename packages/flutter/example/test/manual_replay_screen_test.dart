import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/screens/manual_replay_screen.dart';

void main() {
  group('$ManualReplayScreen', () {
    late Fixture fixture;
    setUp(() => fixture = Fixture());

    testWidgets('stops the previous replay before starting a new scenario', (
      tester,
    ) async {
      await tester.pumpWidget(fixture.getSut());
      await tester.tap(find.text('Opt-in recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send recent activity'));
      await tester.pumpAndSettle();
      expect(fixture.replay.calls, ['stop', 'start', 'stop', 'startBuffering']);
    });

    testWidgets('stops replay before leaving the screen', (tester) async {
      await tester.pumpWidget(fixture.getSut());
      await tester.tap(find.text('Opt-in recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(fixture.replay.calls, ['stop', 'start', 'stop']);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('does not start another scenario when stopping fails', (
      tester,
    ) async {
      fixture.replay.failStop = true;
      await tester.pumpWidget(fixture.getSut());
      await tester.tap(find.text('Opt-in recording'));
      await tester.pumpAndSettle();
      expect(fixture.replay.calls, ['stop']);
      expect(find.textContaining('Call failed'), findsOneWidget);
    });
  });
}

class Fixture {
  final replay = FakeReplay();
  Widget getSut() => MaterialApp(
    initialRoute: '/replay',
    routes: {
      '/': (_) => const Scaffold(body: Text('Home')),
      '/replay': (_) => ManualReplayScreen(replay: replay),
    },
  );
}

class FakeReplay implements SentryReplay {
  final calls = <String>[];
  bool failStop = false;
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> startBuffering() async => calls.add('startBuffering');
  @override
  Future<void> stop() async {
    calls.add('stop');
    if (failStop) throw StateError('stop failed');
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> flush() async => calls.add('flush');
}
