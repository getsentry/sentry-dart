// ignore_for_file: inference_failure_on_function_return_type

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/platform/platform.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'package:meta/meta.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';

import 'mocks.mocks.dart';
import 'no_such_method_provider.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

// https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md#fallback-generators
ISentrySpan startTransactionShim(
  String? name,
  String? operation, {
  String? description,
  DateTime? startTimestamp,
  bool? bindToScope,
  bool? waitForChildren,
  Duration? autoFinishAfter,
  bool? trimEnd,
  Function(ISentrySpan)? onFinish,
  Map<String, dynamic>? customSamplingContext,
}) {
  return MockSentryTracer();
}

@GenerateMocks([
  Transport,
  // ignore: invalid_use_of_internal_member
  SentryTracer,
  MethodChannel,
  SentryNative,
], customMocks: [
  MockSpec<Hub>(fallbackGenerators: {#startTransaction: startTransactionShim})
])
void main() {}

class MockPlatform with NoSuchMethodProvider implements Platform {
  MockPlatform({
    String? os,
    String? osVersion,
    String? hostname,
  })  : operatingSystem = os ?? '',
        operatingSystemVersion = osVersion ?? '',
        localHostname = hostname ?? '';

  factory MockPlatform.android() {
    return MockPlatform(os: 'android');
  }

  factory MockPlatform.iOs() {
    return MockPlatform(os: 'ios');
  }

  factory MockPlatform.macOs() {
    return MockPlatform(os: 'macos');
  }

  factory MockPlatform.windows() {
    return MockPlatform(os: 'windows');
  }

  factory MockPlatform.linux() {
    return MockPlatform(os: 'linux');
  }

  factory MockPlatform.fuchsia() {
    return MockPlatform(os: 'fuchsia');
  }

  @override
  String operatingSystem;

  @override
  String operatingSystemVersion;

  @override
  String localHostname;

  @override
  bool get isLinux => (operatingSystem == 'linux');

  @override
  bool get isMacOS => (operatingSystem == 'macos');

  @override
  bool get isWindows => (operatingSystem == 'windows');

  @override
  bool get isAndroid => (operatingSystem == 'android');

  @override
  bool get isIOS => (operatingSystem == 'ios');

  @override
  bool get isFuchsia => (operatingSystem == 'fuchsia');
}

class MockPlatformChecker with NoSuchMethodProvider implements PlatformChecker {
  MockPlatformChecker({
    this.isDebug = false,
    this.isProfile = false,
    this.isRelease = false,
    this.isWebValue = false,
    this.hasNativeIntegration = false,
    Platform? mockPlatform,
  }) : _mockPlatform = mockPlatform ?? MockPlatform();

  final bool isDebug;
  final bool isProfile;
  final bool isRelease;
  final bool isWebValue;
  final Platform _mockPlatform;

  @override
  bool hasNativeIntegration = false;

  @override
  bool isDebugMode() => isDebug;

  @override
  bool isProfileMode() => isProfile;

  @override
  bool isReleaseMode() => isRelease;

  @override
  bool get isWeb => isWebValue;

  @override
  Platform get platform => _mockPlatform;
}

// Does nothing or returns default values.
// Useful for when a Hub needs to be passed but is not used.
class NoOpHub with NoSuchMethodProvider implements Hub {
  final _options = SentryOptions(dsn: 'fixture-dsn');

  @override
  @internal
  SentryOptions get options => _options;

  @override
  bool get isEnabled => false;
}

class MockNativeChannel implements SentryNativeChannel {
  NativeAppStart? nativeAppStart;
  NativeFrames? nativeFrames;
  SentryId? id;

  int numberOfBeginNativeFramesCalls = 0;
  int numberOfEndNativeFramesCalls = 0;
  int numberOfSetUserCalls = 0;
  int numberOfAddBreadcrumbCalls = 0;
  int numberOfClearBreadcrumbCalls = 0;
  int numberOfRemoveContextsCalls = 0;
  int numberOfRemoveExtraCalls = 0;
  int numberOfRemoveTagCalls = 0;
  int numberOfSetContextsCalls = 0;
  int numberOfSetExtraCalls = 0;
  int numberOfSetTagCalls = 0;

  @override
  Future<NativeAppStart?> fetchNativeAppStart() async => nativeAppStart;

  @override
  Future<void> beginNativeFrames() async {
    numberOfBeginNativeFramesCalls += 1;
  }

  @override
  Future<NativeFrames?> endNativeFrames(SentryId id) async {
    this.id = id;
    numberOfEndNativeFramesCalls += 1;
    return nativeFrames;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    numberOfSetUserCalls += 1;
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    numberOfAddBreadcrumbCalls += 1;
  }

  @override
  Future<void> clearBreadcrumbs() async {
    numberOfClearBreadcrumbCalls += 1;
  }

  @override
  Future<void> removeContexts(String key) async {
    numberOfRemoveContextsCalls += 1;
  }

  @override
  Future<void> removeExtra(String key) async {
    numberOfRemoveExtraCalls += 1;
  }

  @override
  Future<void> removeTag(String key) async {
    numberOfRemoveTagCalls += 1;
  }

  @override
  Future<void> setContexts(String key, value) async {
    numberOfSetContextsCalls += 1;
  }

  @override
  Future<void> setExtra(String key, value) async {
    numberOfSetExtraCalls += 1;
  }

  @override
  Future<void> setTag(String key, value) async {
    numberOfSetTagCalls += 1;
  }
}

class MockRendererWrapper implements RendererWrapper {
  MockRendererWrapper(this._renderer);

  final FlutterRenderer _renderer;

  @override
  FlutterRenderer getRenderer() {
    return _renderer;
  }

  @override
  String getRendererAsString() {
    switch (getRenderer()) {
      case FlutterRenderer.skia:
        return 'Skia';
      case FlutterRenderer.canvasKit:
        return 'CanvasKit';
      case FlutterRenderer.html:
        return 'HTML';
      case FlutterRenderer.unknown:
        return 'Unknown';
    }
  }
}
