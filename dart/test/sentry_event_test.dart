// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/version.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('deserialize', () {
    final sentryId = SentryId.empty();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    final sentryEventJson = <String, dynamic>{
      'event_id': sentryId.toString(),
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
      'platform': 'platform',
      'logger': 'logger',
      'server_name': 'serverName',
      'release': 'release',
      'dist': 'dist',
      'environment': 'environment',
      'modules': {'key': 'value'},
      'message': {'formatted': 'formatted'},
      'transaction': 'transaction',
      'exception': {
        'values': [
          {'type': 'type', 'value': 'value'}
        ]
      },
      'threads': {
        'values': [
          {'id': 0, 'crashed': true}
        ]
      },
      'level': 'debug',
      'culprit': 'culprit',
      'tags': {'key': 'value'},
      'extra': {'key': 'value'},
      'contexts': {
        'device': {'name': 'name'}
      },
      'user': {
        'id': 'id',
        'username': 'username',
        'ip_address': '192.168.0.0.1'
      },
      'fingerprint': ['fingerprint'],
      'breadcrumbs': [
        {
          'message': 'message',
          'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
          'level': 'info'
        }
      ],
      'sdk': {'name': 'name', 'version': 'version'},
      'request': {'url': 'url'},
      'debug_meta': {
        'sdk_info': {'sdk_name': 'sdkName'}
      },
      'type': 'type',
    };
    sentryEventJson.addAll(testUnknown);

    final emptyFieldsSentryEventJson = <String, dynamic>{
      'event_id': sentryId.toString(),
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
      'contexts': {
        'device': {'name': 'name'}
      },
    };

    test('fromJson', () {
      final sentryEvent = SentryEvent.fromJson(sentryEventJson);
      final json = sentryEvent.toJson();

      expect(
        DeepCollectionEquality().equals(sentryEventJson, json),
        true,
      );
    });

    test('should not deserialize null or empty fields', () {
      final sentryEvent = SentryEvent.fromJson(emptyFieldsSentryEventJson);

      expect(sentryEvent.platform, isNull);
      expect(sentryEvent.logger, isNull);
      expect(sentryEvent.serverName, isNull);
      expect(sentryEvent.release, isNull);
      expect(sentryEvent.dist, isNull);
      expect(sentryEvent.environment, isNull);
      expect(sentryEvent.modules, isNull);
      expect(sentryEvent.message, isNull);
      expect(sentryEvent.threads?.first.stacktrace, isNull);
      expect(sentryEvent.exceptions?.first, isNull);
      expect(sentryEvent.transaction, isNull);
      expect(sentryEvent.level, isNull);
      expect(sentryEvent.culprit, isNull);
      expect(sentryEvent.tags, isNull);
      // ignore: deprecated_member_use_from_same_package
      expect(sentryEvent.extra, isNull);
      expect(sentryEvent.breadcrumbs, isNull);
      expect(sentryEvent.user, isNull);
      expect(sentryEvent.fingerprint, isNull);
      expect(sentryEvent.sdk, isNull);
      expect(sentryEvent.request, isNull);
      expect(sentryEvent.debugMeta, isNull);
      expect(sentryEvent.type, isNull);
      expect(sentryEvent.unknown, isNull);
    });
  });

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
      var platformChecker = PlatformChecker();

      final event = SentryEvent(
        eventId: SentryId.empty(),
        timestamp: DateTime.utc(2019),
        platform: sdkPlatform(platformChecker.isWeb),
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
        'platform': platformChecker.isWeb ? 'javascript' : 'other',
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
      var platformChecker = PlatformChecker();

      final timestamp = DateTime.utc(2019);
      final user = SentryUser(
        id: 'user_id',
        username: 'username',
        email: 'email@email.com',
        ipAddress: '127.0.0.1',
        data: const <String, String>{'foo': 'bar'},
      );

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
                platform: sdkPlatform(platformChecker.isWeb),
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
                // ignore: deprecated_member_use_from_same_package
                extra: const <String, dynamic>{
                  'e': 'f',
                  'g': 2,
                },
                fingerprint: const <String>[
                  SentryEvent.defaultFingerprint,
                  'foo'
                ],
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
                type: 'type',
                unknown: testUnknown)
            .toJson(),
        <String, dynamic>{
          'platform': platformChecker.isWeb ? 'javascript' : 'other',
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
            'data': {'foo': 'bar'}
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
          },
          'type': 'type',
        }..addAll(testUnknown),
      );
    });

    test('should not serialize throwable', () {
      final error = StateError('test-error');

      final serialized = SentryEvent(throwable: error).toJson();
      expect(serialized['throwable'], null);
      expect(serialized['stacktrace'], null);
      expect(serialized['exception'], null);
    });

    test('should serialize $SentryThread when no $SentryException present', () {
      final serialized = SentryEvent(threads: [
        SentryThread(
          id: 0,
          crashed: true,
          current: true,
          name: 'Isolate',
        )
      ]).toJson();
      expect(serialized['threads']['values'], isNotNull);
    });

    test('should serialize $SentryThread when id matches exception id', () {
      final serialized = SentryEvent(
        exceptions: [
          SentryException(
            type: 'foo',
            value: 'bar',
            threadId: 0,
          )
        ],
        threads: [
          SentryThread(
            id: 0,
            crashed: true,
            current: true,
            name: 'Isolate',
          )
        ],
      ).toJson();
      expect(serialized['threads']?['values'], isNotEmpty);
    });

    test(
        'should not serialize event.threads.stacktrace '
        'if event.exception is set', () {
      // https://develop.sentry.dev/sdk/event-payloads/stacktrace/
      final stacktrace =
          SentryStackTrace(frames: [SentryStackFrame(function: 'main')]);
      final serialized = SentryEvent(
        exceptions: [
          SentryException(
            value: 'Bad state',
            type: 'StateError',
            threadId: 0,
            stackTrace: stacktrace,
          )
        ],
        threads: [
          SentryThread(
            crashed: true,
            current: true,
            id: 0,
            name: 'Current isolate',
            stacktrace: stacktrace,
          )
        ],
      ).toJson();

      expect(serialized['threads']?['values']?.first['stacktrace'], isNull);
      expect(serialized['threads']?['values']?.first['crashed'], true);
      expect(serialized['threads']?['values']?.first['current'], true);
      expect(serialized['threads']?['values']?.first['id'], 0);
      expect(
        serialized['threads']?['values']?.first['name'],
        'Current isolate',
      );
    });

    test(
        'should serialize event.threads.stacktrace '
        'if event.exception.threadId does not match', () {
      // https://develop.sentry.dev/sdk/event-payloads/stacktrace/
      final stacktrace =
          SentryStackTrace(frames: [SentryStackFrame(function: 'main')]);
      final serialized = SentryEvent(
        exceptions: [
          SentryException(
            value: 'Bad state',
            type: 'StateError',
            threadId: 1,
            stackTrace: stacktrace,
          )
        ],
        threads: [
          SentryThread(
            crashed: true,
            current: true,
            id: 0,
            name: 'Current isolate',
            stacktrace: stacktrace,
          )
        ],
      ).toJson();
      expect(serialized['threads']?['values'], isNotEmpty);
    });

    test('serializes to JSON with sentryException', () {
      SentryException? sentryException;
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

      final serialized = SentryEvent(exceptions: [sentryException]).toJson();

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
        exceptions: [SentryException(type: null, value: null)],
        threads: [SentryThread(stacktrace: SentryStackTrace(frames: []))],
        tags: {},
        // ignore: deprecated_member_use_from_same_package
        extra: {},
        contexts: Contexts(),
        fingerprint: [],
        breadcrumbs: [Breadcrumb()],
        request: SentryRequest(),
        debugMeta: DebugMeta(images: []),
        type: null,
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
      expect(eventMap['type'], isNull);
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
