// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

import '../app_config.dart';
import '../widgets.dart';

class ErrorsScreen extends StatelessWidget {
  const ErrorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Errors')),
      body: SingleChildScrollView(
        child: Center(
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  const TooltipButton(
                    onPressed: tryCatch,
                    key: Key('dart_try_catch'),
                    text: 'Creates a caught exception and sends it to Sentry.',
                    buttonTitle: 'Dart: try catch',
                  ),
                  TooltipButton(
                    onPressed: () => Scaffold.of(context).showBottomSheet(
                        (context) => const Text('Scaffold error')),
                    text:
                        'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Flutter error: Scaffold.of()',
                  ),
                  TooltipButton(
                    // Warning: not captured if a debugger is attached
                    // https://github.com/flutter/flutter/issues/48972
                    onPressed: () => throw Exception('Throws onPressed'),
                    text:
                        'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Dart: throw onPressed',
                  ),
                  TooltipButton(
                    // Warning: not captured if a debugger is attached
                    // https://github.com/flutter/flutter/issues/48972
                    onPressed: () {
                      assert(false, 'assert failure');
                    },
                    text:
                        'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Dart: assert',
                  ),
                  TooltipButton(
                    onPressed: () async => asyncThrows(),
                    text:
                        'Creates an async uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Dart: async throws',
                  ),
                  TooltipButton(
                    onPressed: () async => {
                      await Future.microtask(
                        () => throw StateError('Failure in a microtask'),
                      )
                    },
                    text:
                        'Creates an uncaught exception in a microtask and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Dart: Fail in microtask',
                  ),
                  TooltipButton(
                    onPressed: () async => {
                      await compute(loop, 10),
                    },
                    text:
                        'Creates an uncaught exception in a compute isolate and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Dart: Fail in compute',
                  ),
                  TooltipButton(
                    onPressed: () async => {
                      await Future.delayed(
                        const Duration(milliseconds: 100),
                        () => throw StateError('Failure in a Future.delayed'),
                      ),
                    },
                    text:
                        'Creates an uncaught exception in a Future.delayed and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Throws in Future.delayed',
                  ),
                  TooltipButton(
                    onPressed: () {
                      FlutterError.onError?.call(
                        FlutterErrorDetails(
                          exception: Exception('A really bad exception'),
                          silent: false,
                          context: DiagnosticsNode.message(
                              'while handling a gesture'),
                          library: 'gesture',
                          informationCollector: () => [
                            DiagnosticsNode.message(
                                'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                            DiagnosticsNode.message(
                                'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                            DiagnosticsNode.message(
                                'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                          ],
                        ),
                      );
                    },
                    text:
                        'Creates a FlutterError and passes it to FlutterError.onError callback. This demonstrates how our flutter error integration catches unhandled exceptions.',
                    buttonTitle: 'Capture from FlutterError.onError',
                  ),
                  TooltipButton(
                    onPressed: () {
                      WidgetsBinding.instance.platformDispatcher.onError?.call(
                        Exception('PlatformDispatcher.onError'),
                        StackTrace.current,
                      );
                    },
                    text:
                        'This requires additional setup: options.addIntegration(OnErrorIntegration());',
                    buttonTitle: 'Capture from PlatformDispatcher.onError',
                  ),
                  if (SentryFlutter.native != null)
                    ElevatedButton(
                      onPressed: () async => SentryFlutter.nativeCrash(),
                      child: const Text('Sentry.nativeCrash'),
                    ),
                  if (UniversalPlatform.isIOS || UniversalPlatform.isMacOS)
                    const CocoaExample(),
                  if (UniversalPlatform.isAndroid) const AndroidExample(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> tryCatch() async {
  try {
    throw StateError('try catch');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

Future<void> asyncThrows() async {
  throw StateError('async throws');
}

// Top-level so it shows up correctly in profiles (not as an anonymous closure).
@pragma('vm:never-inline')
int loop(int val) {
  var count = 0;
  for (var i = 1; i <= val; i++) {
    count += i;
  }
  throw StateError('from a compute isolate $count');
}

class AndroidExample extends StatelessWidget {
  const AndroidExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(spacing: 8, children: [
      ElevatedButton(
        onPressed: () async => execute('throw'),
        child: const Text('Kotlin Throw unhandled exception'),
      ),
      ElevatedButton(
        onPressed: () async => execute('capture'),
        child: const Text('Kotlin Capture Exception'),
      ),
      ElevatedButton(
        // ANR is disabled by default, enable it to test it
        onPressed: () async => execute('anr'),
        child: const Text('ANR: Block UI 10s (Press until dialog appears)'),
      ),
      ElevatedButton(
        onPressed: () async => execute('cpp_capture_message'),
        child: const Text('C++ Capture message'),
      ),
      ElevatedButton(
        onPressed: () async => execute('crash'),
        child: const Text('C++ SEGFAULT'),
      ),
      ElevatedButton(
        onPressed: () async => execute('platform_exception'),
        child: const Text('Platform exception'),
      ),
    ]);
  }
}

class CocoaExample extends StatelessWidget {
  const CocoaExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(spacing: 8, children: [
      ElevatedButton(
        onPressed: () async => execute('fatalError'),
        child: const Text('Swift fatalError'),
      ),
      ElevatedButton(
        onPressed: () async => execute('capture'),
        child: const Text('Swift Capture NSException'),
      ),
      ElevatedButton(
        onPressed: () async => execute('capture_message'),
        child: const Text('Swift Capture message'),
      ),
      ElevatedButton(
        onPressed: () async => execute('throw'),
        child: const Text('Objective-C Throw unhandled exception'),
      ),
      ElevatedButton(
        onPressed: () async => execute('crash'),
        child: const Text('Objective-C SEGFAULT'),
      ),
    ]);
  }
}
