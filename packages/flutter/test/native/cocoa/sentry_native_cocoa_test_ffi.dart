import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/cocoa/binding.dart';
import 'package:sentry_flutter/src/native/cocoa/sentry_native_cocoa.dart';

import '../../mocks.dart';

void main() {
  group('$SentryNativeCocoa', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      fixture.close();
    });

    group('addBreadcrumb', () {
      group('when ffi entry point is available', () {
        setUp(() {
          fixture.stubEntryPoints(fixture.entryPointsAddress());
        });

        test('sends normalized breadcrumb json through ffi', () async {
          final sut = fixture.getSut();

          await sut.addBreadcrumb(
            Breadcrumb(
              message: 'fixture-message',
              category: 'fixture-category',
              level: SentryLevel.warning,
              type: 'fixture-type',
              timestamp: DateTime.utc(2024, 1, 15, 12),
              data: {
                'custom': _CustomObject(),
                'nested': {'n': 1},
              },
            ),
          );

          expect(fixture.receivedJson, [
            {
              'message': 'fixture-message',
              'category': 'fixture-category',
              'level': 'warning',
              'type': 'fixture-type',
              'timestamp': '2024-01-15T12:00:00.000Z',
              'data': {
                'custom': 'custom-object',
                'nested': {'n': 1},
              },
            },
          ]);
        });

        test('does not invoke addBreadcrumb method channel', () async {
          final sut = fixture.getSut();

          await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));

          verifyNever(fixture.channel.handler('addBreadcrumb', any));
        });

        test('loads entry points once across concurrent calls', () async {
          final sut = fixture.getSut();

          await Future.wait([
            Future.value(sut.addBreadcrumb(Breadcrumb(message: 'a'))),
            Future.value(sut.addBreadcrumb(Breadcrumb(message: 'b'))),
          ]);
          await sut.addBreadcrumb(Breadcrumb(message: 'c'));

          verify(fixture.channel.handler('ffiEntryPoints', any)).called(1);
          expect(fixture.receivedJson.map((json) => json['message']), [
            'a',
            'b',
            'c',
          ]);
        });
      });

      group('when ffi entry point is unavailable', () {
        setUp(() {
          when(
            fixture.channel.handler('addBreadcrumb', any),
          ).thenAnswer((_) => Future.value());
        });

        test('with null result falls back to method channel', () async {
          fixture.stubEntryPoints(null);
          final sut = fixture.getSut();

          await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));

          verify(fixture.channel.handler('addBreadcrumb', any)).called(1);
        });

        test('with zero address falls back to method channel', () async {
          fixture.stubEntryPoints(0);
          final sut = fixture.getSut();

          await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));

          verify(fixture.channel.handler('addBreadcrumb', any)).called(1);
        });

        test('with null function falls back to method channel', () async {
          fixture.stubEntryPoints(
            fixture.entryPointsAddress(withAddBreadcrumb: false),
          );
          final sut = fixture.getSut();

          await sut.addBreadcrumb(Breadcrumb(message: 'fixture-message'));

          verify(fixture.channel.handler('addBreadcrumb', any)).called(1);
          expect(fixture.receivedJson, isEmpty);
        });
      });
    });
  });
}

class _CustomObject {
  @override
  String toString() => 'custom-object';
}

typedef _AddBreadcrumbNative = Void Function(Pointer<Uint8>, Size);

class Fixture {
  final channel = NativeChannelFixture();
  final receivedJson = <Map<String, dynamic>>[];
  late final NativeCallable<_AddBreadcrumbNative> _nativeAddBreadcrumb =
      NativeCallable<_AddBreadcrumbNative>.isolateLocal(_onAddBreadcrumb);

  final _entryPoints = calloc<SentryFlutterFfiEntryPoints>();

  /// Address of a native entry-points struct, as Swift would hand it over.
  int entryPointsAddress({bool withAddBreadcrumb = true}) {
    _entryPoints.ref.addBreadcrumb = withAddBreadcrumb
        ? _nativeAddBreadcrumb.nativeFunction
        : nullptr;
    return _entryPoints.address;
  }

  void _onAddBreadcrumb(Pointer<Uint8> bytes, int length) {
    final copy = Uint8List.fromList(bytes.asTypedList(length));
    receivedJson.add(jsonDecode(utf8.decode(copy)) as Map<String, dynamic>);
  }

  void stubEntryPoints(int? address) {
    when(
      channel.handler('ffiEntryPoints', any),
    ).thenAnswer((_) => Future.value(address));
  }

  SentryNativeCocoa getSut() {
    final options = defaultTestOptions()
      ..platform = MockPlatform.iOS()
      ..methodChannel = channel.channel;
    return SentryNativeCocoa(options);
  }

  void close() {
    _nativeAddBreadcrumb.close();
    calloc.free(_entryPoints);
  }
}
