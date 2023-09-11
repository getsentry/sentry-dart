import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';

ISentrySpan startTransactionShim(
  String? name,
  String? operation, {
  String? description,
  DateTime? startTimestamp,
  bool? bindToScope,
  bool? waitForChildren,
  Duration? autoFinishAfter,
  bool? trimEnd,
  OnTransactionFinish? onFinish,
  Map<String, dynamic>? customSamplingContext,
}) {
  return MockSentryTracer();
}

//  From a directory that contains a pubspec.yaml file:
//  dart run build_runner build  # Dart SDK
//  flutter pub run build_runner build  # Flutter SDK

@GenerateMocks(
  [
    // ignore: invalid_use_of_internal_member
    SentryTracer,
    Batch,
    Database,
    DatabaseExecutor,
  ],
  customMocks: [
    MockSpec<Hub>(
      fallbackGenerators: {#startTransaction: startTransactionShim},
    ),
  ],
)
void main() {}
