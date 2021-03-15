// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/sentry_request.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:sentry/src/utils.dart';
import 'package:sentry/src/version.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group(SentryEvent, () {
    test('$Breadcrumb serializes', () {
      expect(
        Breadcrumb(
          message: 'example log',
          timestamp: DateTime.utc(2019),
          level: SentryLevel.debug,
          category: 'test',
        ).toJson(),
        <String, dynamic>{
          'timestamp': '2019-01-01T00:00:00.000Z',
          'message': 'example log',
          'category': 'test',
          'level': 'debug',
        },
      );
    });
    test('$SdkVersion serializes', () {
      final event = SentryEvent(
        eventId: SentryId.empty(),
        timestamp: DateTime.utc(2019),
        platform: sdkPlatform,
        sdk: SdkVersion(
          name: 'sentry.dart.flutter',
          version: '4.3.2',
          integrations: <String>['integration'],
          packages: <SentryPackage>[
            SentryPackage('npm:@sentry/javascript', '1.3.4'),
          ],
        ),
      );
      expect(event.toJson(), <String, dynamic>{
        'platform': isWeb ? 'javascript' : 'other',
        'event_id': '00000000000000000000000000000000',
        'timestamp': '2019-01-01T00:00:00.000Z',
        'sdk': {
          'name': 'sentry.dart.flutter',
          'version': '4.3.2',
          'packages': [
            {'name': 'npm:@sentry/javascript', 'version': '1.3.4'}
          ],
          'integrations': ['integration'],
        },
      });
    });
    test('serializes to JSON', () {
      final timestamp = DateTime.utc(2019);
      final user = SentryUser(
          id: 'user_id',
          username: 'username',
          email: 'email@email.com',
          ipAddress: '127.0.0.1',
          extras: const <String, String>{'foo': 'bar'});

      final breadcrumbs = [
        Breadcrumb(
          message: 'test log',
          timestamp: timestamp,
          level: SentryLevel.debug,
          category: 'test',
        ),
      ];

      final request = SentryRequest(
        url: 'https://api.com/users',
        method: 'GET',
        headers: const {'authorization': '123456'},
      );

      expect(
        SentryEvent(
          eventId: SentryId.empty(),
          timestamp: timestamp,
          platform: sdkPlatform,
          message: SentryMessage(
            'test-message 1 2',
            template: 'test-message %d %d',
            params: ['1', '2'],
          ),
          transaction: '/test/1',
          level: SentryLevel.debug,
          culprit: 'Professor Moriarty',
          tags: const <String, String>{
            'a': 'b',
            'c': 'd',
          },
          extra: const <String, dynamic>{
            'e': 'f',
            'g': 2,
          },
          fingerprint: const <String>[SentryEvent.defaultFingerprint, 'foo'],
          user: user,
          breadcrumbs: breadcrumbs,
          request: request,
          debugMeta: DebugMeta(
            sdk: SdkInfo(
              sdkName: 'sentry.dart',
              versionMajor: 4,
              versionMinor: 1,
              versionPatchlevel: 2,
            ),
            images: const <DebugImage>[
              DebugImage(
                type: 'macho',
                debugId: '84a04d24-0e60-3810-a8c0-90a65e2df61a',
                debugFile: 'libDiagnosticMessagesClient.dylib',
                codeFile: '/usr/lib/libDiagnosticMessagesClient.dylib',
                imageAddr: '0x7fffe668e000',
                imageSize: 8192,
                arch: 'x86_64',
                codeId: '123',
              )
            ],
          ),
        ).toJson(),
        <String, dynamic>{
          'platform': isWeb ? 'javascript' : 'other',
          'event_id': '00000000000000000000000000000000',
          'timestamp': '2019-01-01T00:00:00.000Z',
          'message': {
            'formatted': 'test-message 1 2',
            'message': 'test-message %d %d',
            'params': ['1', '2']
          },
          'transaction': '/test/1',
          'level': 'debug',
          'culprit': 'Professor Moriarty',
          'tags': {'a': 'b', 'c': 'd'},
          'extra': {'e': 'f', 'g': 2},
          'fingerprint': ['{{ default }}', 'foo'],
          'user': {
            'id': 'user_id',
            'username': 'username',
            'email': 'email@email.com',
            'ip_address': '127.0.0.1',
            'extras': {'foo': 'bar'}
          },
          'breadcrumbs': {
            {
              'timestamp': '2019-01-01T00:00:00.000Z',
              'message': 'test log',
              'category': 'test',
              'level': 'debug',
            },
          },
          'request': {
            'url': request.url,
            'method': request.method,
            'headers': {'authorization': '123456'}
          },
          'debug_meta': {
            'sdk_info': {
              'sdk_name': 'sentry.dart',
              'version_major': 4,
              'version_minor': 1,
              'version_patchlevel': 2
            },
            'images': [
              <String, dynamic>{
                'type': 'macho',
                'debug_id': '84a04d24-0e60-3810-a8c0-90a65e2df61a',
                'debug_file': 'libDiagnosticMessagesClient.dylib',
                'code_file': '/usr/lib/libDiagnosticMessagesClient.dylib',
                'image_addr': '0x7fffe668e000',
                'image_size': 8192,
                'arch': 'x86_64',
                'code_id': '123',
              },
            ]
          }
        },
      );
    });

    test('should not serialize throwable', () {
      final error = StateError('test-error');

      final serialized = SentryEvent(throwable: error).toJson();
      expect(serialized['throwable'], null);
      expect(serialized['stacktrace'], null);
      expect(serialized['exception'], null);
    });

    test('should serialize stacktrace if SentryStacktrace', () {
      final stacktrace =
          SentryStackTrace(frames: [SentryStackFrame(function: 'main')]);
      final serialized = SentryEvent(stackTrace: stacktrace).toJson();
      expect(serialized['threads']['values'].first['stacktrace'], isNotNull);
    });

    test('should not serialize event.stacktrace if event.exception is set', () {
      final stacktrace =
          SentryStackTrace(frames: [SentryStackFrame(function: 'main')]);
      final serialized = SentryEvent(
        exception: SentryException(value: 'Bad state', type: 'StateError'),
        stackTrace: stacktrace,
      ).toJson();
      expect(serialized['stacktrace'], isNull);
    });

    test('should not serialize stacktrace if not SentryStacktrace', () {
      final stacktrace = SentryStackTrace(
        frames: SentryStackTraceFactory(SentryOptions(dsn: fakeDsn))
            .getStackFrames('#0      baz (file:///pathto/test.dart:50:3)'),
      );
      final serialized = SentryEvent(stackTrace: stacktrace).toJson();
      expect(serialized['stacktrace'], isNull);
    });

    test('serializes to JSON with sentryException', () {
      var sentryException;
      try {
        throw StateError('an error');
      } catch (err) {
        sentryException = SentryException(
          type: '${err.runtimeType}',
          value: '$err',
          mechanism: Mechanism(
            type: 'mech-type',
            description: 'a description',
            helpLink: 'https://help.com',
            synthetic: false,
            handled: true,
            meta: {},
            data: {},
          ),
        );
      }

      final serialized = SentryEvent(exception: sentryException).toJson();

      expect(serialized['exception']['values'].first['type'], 'StateError');
      expect(
        serialized['exception']['values'].first['value'],
        'Bad state: an error',
      );
      expect(
        serialized['exception']['values'].first['mechanism'],
        {
          'type': 'mech-type',
          'description': 'a description',
          'help_link': 'https://help.com',
          'synthetic': false,
          'handled': true,
        },
      );
    });

    test('should not serialize null or empty fields', () {
      final event = SentryEvent(
        message: null,
        modules: {},
        exception: SentryException(type: null, value: null),
        stackTrace: SentryStackTrace(frames: []),
        tags: {},
        extra: {},
        contexts: Contexts(),
        fingerprint: [],
        breadcrumbs: [Breadcrumb()],
        request: SentryRequest(),
        debugMeta: DebugMeta(images: []),
      );
      final eventMap = event.toJson();

      expect(eventMap['message'], isNull);
      expect(eventMap['modules'], isNull);
      expect(eventMap['exception'], isNull);
      expect(eventMap['stacktrace'], isNull);
      expect(eventMap['tags'], isNull);
      expect(eventMap['extra'], isNull);
      expect(eventMap['contexts'], isNull);
      expect(eventMap['fingerprint'], isNull);
      expect(eventMap['request'], isNull);
      expect(eventMap['debug_meta'], isNull);
    });

    test(
        'throwable and throwableMechanism should return the error if no mechanism',
        () {
      final error = StateError('test-error');
      final event = SentryEvent(throwable: error);

      expect(event.throwable, error);
      expect(event.throwableMechanism, error);
    });

    test(
        'throwableMechanism getter should return the ThrowableMechanism if theres a mechanism',
        () {
      final error = StateError('test-error');
      final mechanism = Mechanism(type: 'FlutterError', handled: true);
      final throwableMechanism = ThrowableMechanism(mechanism, error);
      final event = SentryEvent(throwable: throwableMechanism);

      expect(event.throwable, error);
      expect(event.throwableMechanism, throwableMechanism);
    });
  });
}
