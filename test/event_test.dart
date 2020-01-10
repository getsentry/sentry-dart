// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group(Event, () {
    test('$Breadcrumb serializes', () {
      expect(
        Breadcrumb(
          "example log",
          DateTime.utc(2019),
          level: SeverityLevel.debug,
          category: "test",
        ).toJson(),
        <String, dynamic>{
          'timestamp': '2019-01-01T00:00:00',
          'message': 'example log',
          'category': 'test',
          'level': 'debug',
        },
      );
    });
    test('serializes to JSON', () {
      final user = User(
          id: "user_id",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1",
          extras: {"foo": "bar"});

      final breadcrumbs = [
        Breadcrumb("test log", DateTime.utc(2019),
            level: SeverityLevel.debug, category: "test"),
      ];

      expect(
        Event(
          message: 'test-message',
          transaction: '/test/1',
          exception: StateError('test-error'),
          level: SeverityLevel.debug,
          culprit: 'Professor Moriarty',
          tags: <String, String>{
            'a': 'b',
            'c': 'd',
          },
          extra: <String, dynamic>{
            'e': 'f',
            'g': 2,
          },
          fingerprint: <String>[Event.defaultFingerprint, 'foo'],
          userContext: user,
          breadcrumbs: breadcrumbs,
        ).toJson(),
        <String, dynamic>{
          'platform': 'dart',
          'sdk': {'version': sdkVersion, 'name': 'dart'},
          'message': 'test-message',
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
        },
      );
    });
  });
}
