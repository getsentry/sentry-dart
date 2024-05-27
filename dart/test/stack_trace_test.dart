// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_origin.dart'
    if (dart.library.html) 'package:sentry/src/origin.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('encodeStackTraceFrame', () {
    test('marks dart: frames as not app frames', () {
      final frame = Frame(Uri.parse('dart:core'), 1, 2, 'buzz');

      expect(
        Fixture().getSut().encodeStackTraceFrame(frame)!.toJson(),
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

    test('cleans absolute paths', () {
      final frame = Frame(Uri.parse('file://foo/bar/baz.dart'), 1, 2, 'buzz');
      expect(
        Fixture().getSut().encodeStackTraceFrame(frame)!.toJson()['abs_path'],
        '${eventOrigin}baz.dart',
      );
    });

    test('send exception package', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final encodedFrame = Fixture()
          .getSut(inAppExcludes: ['toolkit']).encodeStackTraceFrame(frame)!;
      expect(encodedFrame.package, 'toolkit');
    });

    test('apply inAppExcludes', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame = Fixture()
          .getSut(inAppExcludes: ['toolkit']).encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, false);
    });

    test('apply inAppIncludes', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame = Fixture()
          .getSut(inAppIncludes: ['toolkit']).encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, true);
    });

    test('flutter package is not inApp', () {
      final frame =
          Frame(Uri.parse('package:flutter/material.dart'), 1, 2, 'buzz');
      final serializedFrame = Fixture().getSut().encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, false);
    });

    test('apply inAppIncludes with precedence', () {
      final frame = Frame(Uri.parse('package:toolkit/baz.dart'), 1, 2, 'buzz');
      final serializedFrame = Fixture().getSut(
          inAppExcludes: ['toolkit'],
          inAppIncludes: ['toolkit']).encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, true);
    });

    test('uses default value from options, default = true', () {
      // The following frame meets the following conditions:
      // - frame.uri.scheme is empty
      // - frame.package is null
      // These conditions triggers the default value being used
      final frame = Frame.parseVM('#0 Foo (async/future.dart:0:0)');

      // default is true
      final serializedFrame = Fixture()
          .getSut(considerInAppFramesByDefault: true)
          .encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, true);
    });

    test('uses default value from options, default = false', () {
      // The following frame meets the following conditions:
      // - frame.uri.scheme is empty
      // - frame.package is null
      // These conditions triggers the default value being used
      final frame = Frame.parseVM('#0 Foo (async/future.dart:0:0)');

      // default is true
      final serializedFrame = Fixture()
          .getSut(considerInAppFramesByDefault: false)
          .encodeStackTraceFrame(frame)!;

      expect(serializedFrame.inApp, false);
    });
  });

  group('encodeStackTrace', () {
    test('encodes a simple stack trace', () {
      final frames = Fixture()
          .getSut(considerInAppFramesByDefault: true)
          .getStackFrames('''
#0      baz (file:///pathto/test.dart:50:3)
#1      bar (file:///pathto/test.dart:46:9)
      ''').map((frame) => frame.toJson());

      expect(frames, [
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
      final frames = Fixture()
          .getSut(considerInAppFramesByDefault: true)
          .getStackFrames('''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''').map((frame) => frame.toJson());

      expect(frames, [
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

    test('parses obfuscated stack trace', () {
      final stackTraces = [
        // Older format up to Dart SDK v2.18 (Flutter v3.3)
        '''
warning:  This VM has been configured to produce stack traces that violate the Dart standard.
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
pid: 30930, tid: 30990, name 1.ui
build_id: '5346e01103ffeed44e97094ff7bfcc19'
isolate_dso_base: 723d447000, vm_dso_base: 723d447000
isolate_instructions: 723d452000, vm_instructions: 723d449000
    #00 abs 000000723d6346d7 virt 00000000001ed6d7 _kDartIsolateSnapshotInstructions+0x1e26d7
    #01 abs 000000723d637527 virt 00000000001f0527 _kDartIsolateSnapshotInstructions+0x1e5527
        ''',
        // Newer format
        '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
pid: 19226, tid: 6103134208, name io.flutter.ui
os: macos arch: arm64 comp: no sim: no
isolate_dso_base: 10fa20000, vm_dso_base: 10fa20000
isolate_instructions: 10fa27070, vm_instructions: 10fa21e20
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
    #01 abs 000000723d637527 _kDartIsolateSnapshotInstructions+0x1e5527
        ''',
      ];

      for (var traceString in stackTraces) {
        final frames = Fixture()
            .getSut(considerInAppFramesByDefault: true)
            .getStackFrames(traceString)
            .map((frame) => frame.toJson());

        expect(
            frames,
            [
              {
                'platform': 'native',
                'instruction_addr': '0x000000723d637527',
              },
              {
                'platform': 'native',
                'instruction_addr': '0x000000723d6346d7',
              },
            ],
            reason: "Failed to parse StackTrace:$traceString");
      }
    });

    test('parses normal stack trace', () {
      final frames = Fixture()
          .getSut(considerInAppFramesByDefault: true)
          .getStackFrames('''
#0 asyncThrows (file:/foo/bar/main.dart:404)
#1 MainScaffold.build.<anonymous closure> (package:example/main.dart:131)
#2 PlatformDispatcher._dispatchPointerDataPacket (dart:ui/platform_dispatcher.dart:341)
            ''').map((frame) => frame.toJson());
      expect(frames, [
        {
          'filename': 'platform_dispatcher.dart',
          'function': 'PlatformDispatcher._dispatchPointerDataPacket',
          'lineno': 341,
          'abs_path': '${eventOrigin}dart:ui/platform_dispatcher.dart',
          'in_app': false
        },
        {
          'filename': 'main.dart',
          'package': 'example',
          'function': 'MainScaffold.build.<fn>',
          'lineno': 131,
          'abs_path': '${eventOrigin}package:example/main.dart',
          'in_app': true
        },
        {
          'filename': 'main.dart',
          'function': 'asyncThrows',
          'lineno': 404,
          'abs_path': '${eventOrigin}main.dart',
          'in_app': true
        }
      ]);
    });

    test('remove frames if only async gap is left', () {
      final frames = Fixture()
          .getSut(considerInAppFramesByDefault: true)
          .getStackFrames(StackTrace.fromString('''
<asynchronous suspension>
            '''))
          .map((frame) => frame.toJson());
      expect(frames.isEmpty, true);
    });
  });
}

class Fixture {
  SentryStackTraceFactory getSut({
    List<String> inAppIncludes = const [],
    List<String> inAppExcludes = const [],
    bool considerInAppFramesByDefault = true,
  }) {
    final options = SentryOptions(dsn: fakeDsn);
    inAppIncludes.forEach(options.addInAppInclude);
    inAppExcludes.forEach(options.addInAppExclude);
    options.considerInAppFramesByDefault = considerInAppFramesByDefault;

    return SentryStackTraceFactory(options);
  }
}
