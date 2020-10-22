// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:stack_trace/stack_trace.dart';

/// Sentry.io JSON encoding of a stack frame for the asynchronous suspension,
/// which is the gap between asynchronous calls.
const Map<String, dynamic> asynchronousGapFrameJson = <String, dynamic>{
  'abs_path': '<asynchronous suspension>',
};

/// Encodes [stackTrace] as JSON in the Sentry.io format.
///
/// [stackTrace] must be [String] or [StackTrace].
List<Map<String, dynamic>> encodeStackTrace(
  dynamic stackTrace, {
  String origin,
}) {
  assert(stackTrace is String || stackTrace is StackTrace);
  origin ??= '';

  final chain = stackTrace is StackTrace
      ? Chain.forTrace(stackTrace)
      : Chain.parse(stackTrace as String);

  final frames = <Map<String, dynamic>>[];
  for (var t = 0; t < chain.traces.length; t += 1) {
    final encodedFrames = chain.traces[t].frames
        .map((f) => encodeStackTraceFrame(f, origin: origin));

    frames.addAll(encodedFrames);

    if (t < chain.traces.length - 1) {
      frames.add(asynchronousGapFrameJson);
    }
  }

  return frames.reversed.toList();
}

Map<String, dynamic> encodeStackTraceFrame(Frame frame, {String origin}) {
  origin ??= '';

  final json = <String, dynamic>{
    'abs_path': '$origin${_absolutePathForCrashReport(frame)}',
    'function': frame.member,
    'lineno': frame.line,
    'colno': frame.column,
    'in_app': !frame.isCore,
  };

  if (frame.uri.pathSegments.isNotEmpty) {
    json['filename'] = frame.uri.pathSegments.last;
  }

  return json;
}

/// A stack frame's code path may be one of "file:", "dart:" and "package:".
///
/// Absolute file paths may contain personally identifiable information, and
/// therefore are stripped to only send the base file name. For example,
/// "/foo/bar/baz.dart" is reported as "baz.dart".
///
/// "dart:" and "package:" imports are always relative and are OK to send in
/// full.
String _absolutePathForCrashReport(Frame frame) {
  if (frame.uri.scheme != 'dart' && frame.uri.scheme != 'package') {
    return frame.uri.pathSegments.last;
  }

  return '${frame.uri}';
}
