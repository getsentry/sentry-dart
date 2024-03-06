import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/task_queue.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group("called sync", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test("enqueue only executed `maxQueueSize` times when not awaiting",
        () async {
      final sut = fixture.getSut(maxQueueSize: 5);

      var completedTasks = 0;

      for (int i = 0; i < 10; i++) {
        unawaited(sut.enqueue(() async {
          print('Task $i');
          await Future.delayed(Duration(milliseconds: 1));
          completedTasks += 1;
          return 1 + 1;
        }, -1));
      }

      // This will always await the other futures, even if they are running longer, as it was scheduled after them.
      print('Started waiting for first 5 tasks');
      await Future.delayed(Duration(milliseconds: 1));
      print('Stopped waiting for first 5 tasks');

      expect(completedTasks, 5);
    });

    test("enqueue picks up tasks again after await in-between", () async {
      final sut = fixture.getSut(maxQueueSize: 5);

      var completedTasks = 0;

      for (int i = 1; i <= 10; i++) {
        unawaited(sut.enqueue(() async {
          print('Started task $i');
          await Future.delayed(Duration(milliseconds: 1));
          print('Completed task $i');
          completedTasks += 1;
          return 1 + 1;
        }, -1));
      }

      print('Started waiting for first 5 tasks');
      await Future.delayed(Duration(milliseconds: 1));
      print('Stopped waiting for first 5 tasks');

      for (int i = 6; i <= 15; i++) {
        unawaited(sut.enqueue(() async {
          print('Started task $i');
          await Future.delayed(Duration(milliseconds: 1));
          print('Completed task $i');
          completedTasks += 1;
          return 1 + 1;
        }, -1));
      }

      print('Started waiting for second 5 tasks');
      await Future.delayed(Duration(milliseconds: 5));
      print('Stopped waiting for second 5 tasks');

      expect(completedTasks, 10); // 10 were dropped
    });

    test("enqueue executes all tasks when awaiting", () async {
      final sut = fixture.getSut(maxQueueSize: 5);

      var completedTasks = 0;

      for (int i = 0; i < 10; i++) {
        await sut.enqueue(() async {
          print('Task $i');
          await Future.delayed(Duration(milliseconds: 1));
          completedTasks += 1;
          return 1 + 1;
        }, -1);
      }
      expect(completedTasks, 10);
    });

    test("throwing tasks still execute as expected", () async {
      final sut = fixture.getSut(maxQueueSize: 5);

      var completedTasks = 0;

      for (int i = 0; i < 10; i++) {
        try {
          await sut.enqueue(() async {
            completedTasks += 1;
            throw Error();
          }, -1);
        } catch (_) {
          // Ignore
        }
      }
      expect(completedTasks, 10);
    });
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  TaskQueue<int> getSut({required int maxQueueSize}) {
    return TaskQueue(maxQueueSize, options.logger);
  }
}
