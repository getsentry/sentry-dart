import 'package:sentry/src/utils/stack_trace_utils.dart';
import 'package:test/test.dart';

void main() {
  final dartStackTrace = '''
randomPrefix
#0      main (file:///Users/denis/Repos/other/dart-stacktrace/main.dart:2:20)
#1      _delayEntrypointInvocation.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:296:19)
#2      _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:189:12)
randomSuffix
    ''';

  final flutterStackTrace = '''
randomPrefix
flutter: #0      MainScaffold.build.<anonymous closure> (package:sentry_flutter_example/main.dart:142:47)
#1      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1154:21)
#2      GestureRecognizer.invokeCallback (package:flutter/src/gestures/recognizer.dart:275:24)
#3      TapGestureRecognizer.handleTapUp (package:flutter/src/gestures/tap.dart:654:11)
#4      BaseTapGestureRecognizer._checkUp (package:flutter/src/gestures/tap.dart:311:5)
#5      BaseTapGestureRecognizer.acceptGesture (package:flutter/src/gestures/tap.dart:281:7)
#6      GestureArenaManager.sweep (package:flutter/src/gestures/arena.dart:167:27)
#7      GestureBinding.handleEvent (package:flutter/src/gestures/binding.dart:469:20)
#8      GestureBinding.dispatchEvent (package:flutter/src/gestures/binding.dart:445:22)
#9      RendererBinding.dispatchEvent (package:flutter/src/rendering/binding.dart:331:11)
#10     GestureBinding._handlePointerEventImmediately (package:flutter/src/gestures/binding.dart:400:7)<…>
randomSuffix
    ''';

  final flutterObfuscatedStackTrace = '''
#00 abs 00000075266c2fbf virt 0000000000697fbf _kDartIsolateSnapshotInstructions+0x37e63f
#1 abs 000000752685211f virt 000000000082711f _kDartIsolateSnapshotInstructions+0x50d79f
#2 abs 0000007526851cb3 virt 0000000000826cb3 _kDartIsolateSnapshotInstructions+0x50d333
#3 abs 0000007526851c63 virt 0000000000826c63 _kDartIsolateSnapshotInstructions+0x50d2e3
#4 abs 0000007526851bf3 virt 0000000000826bf3 _kDartIsolateSnapshotInstructions+0x50d273
    ''';

  test('dart stack trace detected', () {
    expect(dartStackTrace.isStackTrace(), isTrue);
  });

  test('flutter stack trace detected', () {
    expect(flutterStackTrace.isStackTrace(), isTrue);
  });

  test('flutter obfuscated stack trace detected', () {
    expect(flutterObfuscatedStackTrace.isStackTrace(), isTrue);
  });

  test('stack trace not detected with frame number only', () {
    expect('#0'.isStackTrace(), isFalse);
  });

  test('stack trace not detected with file name and line number only', () {
    expect('foo.dart:9000:1)'.isStackTrace(), isFalse);
  });

  test('stack trace not detected abs only', () {
    expect(' abs '.isStackTrace(), isFalse);
  });

  test('stack trace not detected virt only', () {
    expect(' virt '.isStackTrace(), isFalse);
  });

  test('stack trace not detected abs & virt only', () {
    expect(
        ' abs 00000075266c2fbf virt 0000000000697fbf'.isStackTrace(), isFalse);
  });

  test('stack trace not detected hex suffix only', () {
    expect(
        '_kDartIsolateSnapshotInstructions+0x50d273'.isStackTrace(), isFalse);
  });
}
