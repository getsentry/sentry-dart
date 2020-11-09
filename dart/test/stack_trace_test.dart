// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_origin.dart'
    if (dart.library.html) 'package:sentry/src/protocol/origin.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

void main() {
  group('encodeStackTraceFrame', () {
    test('marks dart: frames as not app frames', () {
      final frame = Frame(Uri.parse('dart:core'), 1, 2, 'buzz');

      expect(
        SentryStackTraceFactory(SentryOptions())
            .encodeStackTraceFrame(frame)
            .toJson(),
        {
          'abs_path': '${eventOrigin}dart:core',
          'function': 'buzz',
          'lineno': 1,
          'colno': 2,
          'in_app': false,
          'filename': 'core'
        },
      );
    });

    test('cleanses absolute paths', () {
      final frame = Frame(Uri.parse('file://foo/bar/baz.dart'), 1, 2, 'buzz');
      expect(
        SentryStackTraceFactory(SentryOptions())
            .encodeStackTraceFrame(frame)
            .toJson()['abs_path'],
        '${eventOrigin}baz.dart',
      );
    });

    test('send exception package', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame =
          SentryStackTraceFactory(SentryOptions()..addInAppExclude('toolkit'))
              .encodeStackTraceFrame(frame)
              .toJson();
      expect(serializedFrame['package'], 'toolkit');
    });

    test('send exception inAppExcludes', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame =
          SentryStackTraceFactory(SentryOptions()..addInAppExclude('toolkit'))
              .encodeStackTraceFrame(frame)
              .toJson();
      expect(serializedFrame['in_app'], false);
    });

    test('send exception inAppIncludes', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame =
          SentryStackTraceFactory(SentryOptions()..addInAppInclude('toolkit'))
              .encodeStackTraceFrame(frame)
              .toJson();
      expect(serializedFrame['in_app'], true);
    });

    test('send exception inAppIncludes precedence', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame = SentryStackTraceFactory(SentryOptions()
            ..addInAppInclude('toolkit')
            ..addInAppExclude('toolkit'))
          .encodeStackTraceFrame(frame)
          .toJson();
      expect(serializedFrame['in_app'], true);
    });
  });

  group('encodeStackTrace', () {
    test('encodes a simple stack trace', () {
      expect(SentryStackTraceFactory(SentryOptions()).getStackFrames('''
#0      baz (file:///pathto/test.dart:50:3)
#1      bar (file:///pathto/test.dart:46:9)
      ''').map((frame) => frame.toJson()), [
        {
          'abs_path': '${eventOrigin}test.dart',
          'function': 'bar',
          'lineno': 46,
          'colno': 9,
          'in_app': true,
          'filename': 'test.dart'
        },
        {
          'abs_path': '${eventOrigin}test.dart',
          'function': 'baz',
          'lineno': 50,
          'colno': 3,
          'in_app': true,
          'filename': 'test.dart'
        },
      ]);
    });

    test('encodes an asynchronous stack trace', () {
      expect(SentryStackTraceFactory(SentryOptions()).getStackFrames('''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''').map((frame) => frame.toJson()), [
        {
          'abs_path': '${eventOrigin}test.dart',
          'function': 'bar',
          'lineno': 46,
          'colno': 9,
          'in_app': true,
          'filename': 'test.dart'
        },
        {
          'abs_path': '<asynchronous suspension>',
        },
        {
          'abs_path': '${eventOrigin}test.dart',
          'function': 'baz',
          'lineno': 50,
          'colno': 3,
          'in_app': true,
          'filename': 'test.dart'
        },
      ]);
    });
  });
}
