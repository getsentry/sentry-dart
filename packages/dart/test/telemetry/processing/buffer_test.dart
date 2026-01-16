import 'dart:convert';

import 'package:sentry/src/telemetry/processing/in_memory_buffer.dart';
import 'package:sentry/src/telemetry/processing/buffer_config.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryTelemetryBuffer', () {
    late _SimpleFixture fixture;

    setUp(() {
      fixture = _SimpleFixture();
    });

    test('items are flushed after timeout', () async {
      final flushTimeout = Duration(milliseconds: 1);
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(flushTimeout: flushTimeout),
      );

      buffer.add(_TestItem('item1'));
      buffer.add(_TestItem('item2'));

      expect(fixture.flushedItems, isEmpty);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(2));
    });

    test('items exceeding max size are flushed immediately', () async {
      // Each item encodes to ~14 bytes ({"id":"item1"}), so 20 bytes triggers flush on 2nd item
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(maxBufferSizeBytes: 20),
      );

      buffer.add(_TestItem('item1'));
      expect(fixture.flushCallCount, 0);

      buffer.add(_TestItem('item2'));

      // Wait briefly for async flush
      await Future.delayed(Duration(milliseconds: 1));

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(2));
    });

    test('single item exceeding max buffer size is rejected', () async {
      // Set max buffer size to 10 bytes, but item encodes to ~14 bytes
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(maxBufferSizeBytes: 10),
      );

      buffer.add(_TestItem('item1'));

      // Item should be rejected, not added to buffer
      await buffer.flush();

      expect(fixture.flushedItems, isEmpty);
    });

    test('items exceeding max item count are flushed immediately', () async {
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(maxItemCount: 2),
      );

      buffer.add(_TestItem('item1'));
      expect(fixture.flushCallCount, 0);

      buffer.add(_TestItem('item2'));

      // Wait briefly for async flush
      await Future.delayed(Duration(milliseconds: 1));

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(2));
    });

    test('calling flush directly sends items', () async {
      final buffer = fixture.getSut();

      buffer.add(_TestItem('item1'));
      buffer.add(_TestItem('item2'));

      await buffer.flush();

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(2));
    });

    test('timer is only started once and not restarted on subsequent additions',
        () async {
      final flushTimeout = Duration(milliseconds: 100);
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(flushTimeout: flushTimeout),
      );

      buffer.add(_TestItem('item1'));
      expect(fixture.flushCallCount, 0);

      buffer.add(_TestItem('item2'));
      expect(fixture.flushCallCount, 0);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(2));
    });

    test('flush with empty buffer returns null', () async {
      final buffer = fixture.getSut();

      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.flushedItems, isEmpty);
    });

    test('buffer is cleared after flush', () async {
      final buffer = fixture.getSut();

      buffer.add(_TestItem('item1'));
      await buffer.flush();

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedItems, hasLength(1));

      // Second flush should not send anything
      fixture.reset();
      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.flushCallCount, 0);
      expect(fixture.flushedItems, isEmpty);
    });

    test('encoding failure does not crash and item is skipped', () async {
      final buffer = fixture.getSut();

      buffer.add(_ThrowingTestItem());
      buffer.add(_TestItem('valid'));
      await buffer.flush();

      // Only the valid item should be in the buffer
      expect(fixture.flushedItems, hasLength(1));
      expect(fixture.flushCallCount, 1);
    });

    test('onFlush receives List<List<int>> directly', () async {
      final buffer = fixture.getSut();

      buffer.add(_TestItem('item1'));
      buffer.add(_TestItem('item2'));
      await buffer.flush();

      // Verify callback received a simple list, not a map
      expect(fixture.flushedItems, hasLength(2));
      expect(fixture.flushCallCount, 1);
    });
  });

  group('GroupedInMemoryTelemetryBuffer', () {
    late _GroupedFixture fixture;

    setUp(() {
      fixture = _GroupedFixture();
    });

    test('items are grouped by key', () async {
      final buffer = fixture.getSut(
        groupKeyExtractor: (item) => item.group,
      );

      buffer.add(_TestItem('item1', group: 'group1'));
      buffer.add(_TestItem('item2', group: 'group2'));
      buffer.add(_TestItem('item3', group: 'group1'));

      await buffer.flush();

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedGroups.keys, containsAll(['group1', 'group2']));
      expect(fixture.flushedGroups['group1']?.$1, hasLength(2));
      expect(fixture.flushedGroups['group2']?.$1, hasLength(1));
    });

    test('items are flushed after timeout', () async {
      final flushTimeout = Duration(milliseconds: 1);
      final buffer = fixture.getSut(
        config: TelemetryBufferConfig(flushTimeout: flushTimeout),
        groupKeyExtractor: (item) => item.group,
      );

      buffer.add(_TestItem('item1', group: 'a'));
      buffer.add(_TestItem('item2', group: 'b'));

      expect(fixture.flushedGroups, isEmpty);

      await Future.delayed(flushTimeout + Duration(milliseconds: 10));

      expect(fixture.flushCallCount, 1);
      expect(fixture.flushedGroups.keys, hasLength(2));
    });

    test('flush with empty buffer returns null', () async {
      final buffer = fixture.getSut(
        groupKeyExtractor: (item) => item.group,
      );

      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.flushedGroups, isEmpty);
    });

    test('buffer is cleared after flush', () async {
      final buffer = fixture.getSut(
        groupKeyExtractor: (item) => item.group,
      );

      buffer.add(_TestItem('item1', group: 'a'));
      await buffer.flush();

      expect(fixture.flushCallCount, 1);

      fixture.reset();
      final result = buffer.flush();

      expect(result, isNull);
      expect(fixture.flushCallCount, 0);
    });

    test('onFlush receives Map<String, List<List<int>>>', () async {
      final buffer = fixture.getSut(
        groupKeyExtractor: (item) => item.group,
      );

      buffer.add(_TestItem('item1', group: 'myGroup'));
      await buffer.flush();

      expect(fixture.flushedGroups.containsKey('myGroup'), isTrue);
    });
  });
}

class _TestItem {
  final String id;
  final String group;

  _TestItem(this.id, {this.group = 'default'});

  Map<String, dynamic> toJson() => {'id': id};
}

class _ThrowingTestItem extends _TestItem {
  _ThrowingTestItem() : super('throwing');

  @override
  Map<String, dynamic> toJson() => throw Exception('Encoding failed');
}

class _SimpleFixture {
  List<List<int>> flushedItems = [];
  int flushCallCount = 0;

  InMemoryTelemetryBuffer<_TestItem> getSut({
    TelemetryBufferConfig config = const TelemetryBufferConfig(),
  }) {
    return InMemoryTelemetryBuffer<_TestItem>(
      encoder: (item) => utf8.encode(jsonEncode(item.toJson())),
      onFlush: (items) {
        flushCallCount++;
        flushedItems = items;
      },
      config: config,
    );
  }

  void reset() {
    flushedItems = [];
    flushCallCount = 0;
  }
}

class _GroupedFixture {
  Map<String, (List<List<int>>, _TestItem)> flushedGroups = {};
  int flushCallCount = 0;

  GroupedInMemoryTelemetryBuffer<_TestItem> getSut({
    required GroupKeyExtractor<_TestItem> groupKeyExtractor,
    TelemetryBufferConfig config = const TelemetryBufferConfig(),
  }) {
    return GroupedInMemoryTelemetryBuffer<_TestItem>(
      encoder: (item) => utf8.encode(jsonEncode(item.toJson())),
      onFlush: (groups) {
        flushCallCount++;
        flushedGroups = groups;
      },
      groupKeyExtractor: groupKeyExtractor,
      config: config,
    );
  }

  void reset() {
    flushedGroups = {};
    flushCallCount = 0;
  }
}
