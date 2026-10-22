// ignore_for_file: invalid_use_of_internal_member, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jni/jni.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/binding.dart' as native;
import 'package:sentry_flutter/src/native/java/android_core_worker.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';

import 'utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SentryFlutter native lifecycle', () {
    tearDown(Sentry.close);

    group('during worker handoff', () {
      late _Fixture fixture;

      setUp(() {
        fixture = _Fixture();
      });

      for (final closeWhileDraining in [false, true]) {
        testWidgets('keeps the native user cleared after retiring updates '
            '(closing: $closeWhileDraining)', (tester) async {
          await restoreFlutterOnErrorAfter(() async {
            await SentryFlutter.init((options) {
              options.dsn = fakeDsn;
            }, appRunner: () async {});
          });
          final worker = fixture.getSut();
          await worker.start();
          final updating = worker.setUser(SentryUser(id: 'previous-user'));

          worker.stop();
          final clearing = worker.setUser(null);
          final closing = closeWhileDraining ? worker.close() : null;
          fixture.releaseUpdates();
          await updating;
          await clearing;
          await closing;

          using((arena) {
            final adapter = native.ScopesAdapter.instance!..releasedBy(arena);
            final scope = adapter.scope..releasedBy(arena);
            final user = scope.as(native.Scope.type).user;
            user?.releasedBy(arena);
            expect(user, isNull);
          });
        }, skip: !Platform.isAndroid);
      }
    });

    testWidgets('keeps native reporting enabled across detach and reattach', (
      tester,
    ) async {
      await restoreFlutterOnErrorAfter(() async {
        await SentryFlutter.init((options) {
          options.dsn = fakeDsn;
          options.debug = true;
        }, appRunner: () async {});
      });
      expect(native.Sentry.isEnabled, isTrue);

      await _lifecycle(binding, AppLifecycleState.resumed);
      await _lifecycle(binding, AppLifecycleState.detached);
      await tester.pump();
      await _lifecycle(binding, AppLifecycleState.resumed);
      await tester.pump();

      expect(native.Sentry.isEnabled, isTrue);
      final eventId = using((arena) {
        final message = 'Native capture after reattach'.toJString()
          ..releasedBy(arena);
        final id = native.Sentry.captureMessage(message)..releasedBy(arena);
        return id.toString$1().use((value) => value?.toDartString());
      });
      expect(eventId, isNotNull);
      expect(eventId, isNot(const SentryId.empty().toString()));
    }, skip: !Platform.isAndroid);
  });
}

Future<void> _lifecycle(
  IntegrationTestWidgetsFlutterBinding binding,
  AppLifecycleState state,
) async {
  await binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage('AppLifecycleState.${state.name}'),
    (_) {},
  );
}

class _Fixture {
  final _updates = Completer<void>();

  AndroidCoreWorker getSut() {
    final worker = AndroidCoreWorker(
      Sentry.currentHub.options,
      spawn: (config, entry) async =>
          _GatedWorker(await spawnWorker(config, entry), _updates.future),
    );
    addTearDown(() async {
      releaseUpdates();
      await worker.close();
    });
    return worker;
  }

  void releaseUpdates() {
    if (!_updates.isCompleted) _updates.complete();
  }
}

// Delay transport to the real isolate so an outstanding JNI write spans stop().
class _GatedWorker implements Worker {
  final Worker _worker;
  Future<void> _queue;

  _GatedWorker(this._worker, this._queue);

  @override
  Future<Object?> request(Object? payload) {
    final response = _queue.then((_) => _worker.request(payload));
    _queue = response.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return response;
  }

  @override
  void send(Object? message) {
    _queue = _queue.then((_) => _worker.send(message));
  }

  @override
  void close() {
    unawaited(_queue.then((_) => _worker.close()));
  }

  @override
  void closeOnOwnerExit() => _worker.closeOnOwnerExit();

  @override
  SendPort get port => _worker.port;
}
