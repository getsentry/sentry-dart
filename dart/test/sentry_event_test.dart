// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/request.dart';
import 'package:sentry/src/utils.dart';
import 'package:test/test.dart';
import 'package:sentry/src/version.dart';

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
      const user = User(
          id: 'user_id',
          username: 'username',
          email: 'email@email.com',
          ipAddress: '127.0.0.1',
          extras: <String, String>{'foo': 'bar'});

      final breadcrumbs = [
        Breadcrumb(
            message: 'test log',
            timestamp: timestamp,
            level: SentryLevel.debug,
            category: 'test'),
      ];

      final request = Request(url: 'https://api.com/users', method: 'GET');

      expect(
        SentryEvent(
          eventId: SentryId.empty(),
          timestamp: timestamp,
          platform: sdkPlatform,
          message: Message(
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
            images: [
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
          'sdk': {'version': sdkVersion, 'name': sdkName},
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
            'values': [
              {
                'timestamp': '2019-01-01T00:00:00.000Z',
                'message': 'test log',
                'category': 'test',
                'level': 'debug',
              },
            ]
          },
          'request': {
            'url': request.url,
            'method': request.method,
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
  });
}
