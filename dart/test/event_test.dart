// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:sentry/src/stack_trace.dart';
import 'package:sentry/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group(SentryEvent, () {
    test('$Breadcrumb serializes', () {
      expect(
        Breadcrumb(
          'example log',
          DateTime.utc(2019),
          level: SentryLevel.debug,
          category: 'test',
        ).toJson(),
        <String, dynamic>{
          'timestamp': '2019-01-01T00:00:00',
          'message': 'example log',
          'category': 'test',
          'level': 'debug',
        },
      );
    });
    test('$Sdk serializes', () {
      final event = SentryEvent(
        eventId: SentryId.empty(),
        timestamp: DateTime.utc(2019),
        platform: sdkPlatform,
        sdk: Sdk(
          name: 'sentry.dart.flutter',
          version: '4.3.2',
          integrations: <String>['integration'],
          packages: <Package>[
            Package('npm:@sentry/javascript', '1.3.4'),
          ],
        ),
      );
      expect(event.toJson(), <String, dynamic>{
        'platform': isWeb ? 'javascript' : 'dart',
        'event_id': '00000000000000000000000000000000',
        'timestamp': '2019-01-01T00:00:00',
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
        Breadcrumb('test log', timestamp,
            level: SentryLevel.debug, category: 'test'),
      ];

      final error = StateError('test-error');

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
          exception: error,
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
          userContext: user,
          breadcrumbs: breadcrumbs,
        ).toJson(),
        <String, dynamic>{
          'platform': isWeb ? 'javascript' : 'dart',
          'event_id': '00000000000000000000000000000000',
          'timestamp': '2019-01-01T00:00:00',
          'sdk': {'version': sdkVersion, 'name': sdkName},
          'message': {
            'formatted': 'test-message 1 2',
            'message': 'test-message %d %d',
            'params': ['1', '2']
          },
          'transaction': '/test/1',
          'exception': [
            {'type': 'StateError', 'value': 'Bad state: test-error'}
          ],
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
                'timestamp': '2019-01-01T00:00:00',
                'message': 'test log',
                'category': 'test',
                'level': 'debug',
              },
            ]
          },
        }..addAll(
            error.stackTrace == null
                ? {}
                : {
                    'stacktrace': {
                      'frames': encodeStackTrace(
                        error.stackTrace,
                        origin: null,
                      )
                    }
                  },
          ),
      );
    });
  });
}
