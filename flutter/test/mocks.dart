// ignore_for_file: inference_failure_on_function_return_type

import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/src/platform/platform.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'package:meta/meta.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import 'mocks.mocks.dart';
import 'no_such_method_provider.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';
const fakeProguardUuid = '3457d982-65ef-576d-a6ad-65b5f30f49a5';

// TODO use this everywhere in tests so that we don't get exceptions swallowed.
SentryFlutterOptions defaultTestOptions() {
  // ignore: invalid_use_of_internal_member
  return SentryFlutterOptions(dsn: fakeDsn)..automatedTestMode = true;
}

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
  SentryTransaction,
  SentrySpan,
  MethodChannel,
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
  final _options = defaultTestOptions();

  @override
  @internal
  SentryOptions get options => _options;

  @override
  bool get isEnabled => false;
}

// TODO can this be replaced with https://pub.dev/packages/mockito#verifying-exact-number-of-invocations--at-least-x--never
class TestMockSentryNative implements SentryNative {
  @override
  DateTime? appStartEnd;

  bool _didFetchAppStart = false;

  @override
  bool get didFetchAppStart => _didFetchAppStart;

  @override
  bool didAddAppStartMeasurement = false;

  Breadcrumb? breadcrumb;
  var numberOfAddBreadcrumbCalls = 0;
  var numberOfBeginNativeFramesCollectionCalls = 0;
  var numberOfClearBreadcrumbsCalls = 0;
  var numberOfEndNativeFramesCollectionCalls = 0;
  var numberOfFetchNativeAppStartCalls = 0;
  var removeContextsKey = '';
  var numberOfRemoveContextsCalls = 0;
  var removeExtraKey = '';
  var numberOfRemoveExtraCalls = 0;
  var removeTagKey = '';
  var numberOfRemoveTagCalls = 0;
  var numberOfResetCalls = 0;
  Map<String, dynamic> setContextData = {};
  var numberOfSetContextsCalls = 0;
  Map<String, dynamic> setExtraData = {};
  var numberOfSetExtraCalls = 0;
  Map<String, String> setTagsData = {};
  var numberOfSetTagCalls = 0;
  SentryUser? sentryUser;
  var numberOfSetUserCalls = 0;
  var numberOfStartProfilerCalls = 0;
  var numberOfDiscardProfilerCalls = 0;
  var numberOfCollectProfileCalls = 0;
  var numberOfInitCalls = 0;
  SentryFlutterOptions? initOptions;
  var numberOfCloseCalls = 0;

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    this.breadcrumb = breadcrumb;
    numberOfAddBreadcrumbCalls++;
  }

  @override
  Future<void> beginNativeFramesCollection() async {
    numberOfBeginNativeFramesCollectionCalls++;
  }

  @override
  Future<void> clearBreadcrumbs() async {
    numberOfClearBreadcrumbsCalls++;
  }

  @override
  Future<NativeFrames?> endNativeFramesCollection(SentryId traceId) async {
    numberOfEndNativeFramesCollectionCalls++;
    return null;
  }

  @override
  Future<NativeAppStart?> fetchNativeAppStart() async {
    _didFetchAppStart = true;
    numberOfFetchNativeAppStartCalls++;
    return null;
  }

  @override
  Future<void> removeContexts(String key) async {
    removeContextsKey = key;
    numberOfRemoveContextsCalls++;
  }

  @override
  Future<void> removeExtra(String key) async {
    removeExtraKey = key;
    numberOfRemoveExtraCalls++;
  }

  @override
  Future<void> removeTag(String key) async {
    removeTagKey = key;
    numberOfRemoveTagCalls++;
  }

  @override
  void reset() {
    numberOfResetCalls++;
  }

  @override
  Future<void> setContexts(String key, value) async {
    setContextData[key] = value;
    numberOfSetContextsCalls++;
  }

  @override
  Future<void> setExtra(String key, value) async {
    setExtraData[key] = value;
    numberOfSetExtraCalls++;
  }

  @override
  Future<void> setTag(String key, String value) async {
    setTagsData[key] = value;
    numberOfSetTagCalls++;
  }

  @override
  Future<void> setUser(SentryUser? sentryUser) async {
    this.sentryUser = sentryUser;
    numberOfSetUserCalls++;
  }

  @override
  Future<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    numberOfCollectProfileCalls++;
    return Future.value(null);
  }

  @override
  int? startProfiler(SentryId traceId) {
    numberOfStartProfilerCalls++;
    return 42;
  }

  @override
  Future<void> discardProfiler(SentryId traceId) {
    numberOfDiscardProfilerCalls++;
    return Future.value(null);
  }

  @override
  Future<void> init(SentryFlutterOptions options) {
    numberOfInitCalls++;
    initOptions = options;
    return Future.value(null);
  }

  @override
  Future<void> close() {
    numberOfCloseCalls++;
    return Future.value(null);
  }
}

// TODO can this be replaced with https://pub.dev/packages/mockito#verifying-exact-number-of-invocations--at-least-x--never
class MockNativeChannel implements SentryNativeBinding {
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
  int numberOfStartProfilerCalls = 0;
  int numberOfDiscardProfilerCalls = 0;
  int numberOfCollectProfileCalls = 0;
  int numberOfInitCalls = 0;
  int numberOfCloseCalls = 0;

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

  @override
  Future<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    numberOfCollectProfileCalls++;
    return Future.value(null);
  }

  @override
  int? startProfiler(SentryId traceId) {
    numberOfStartProfilerCalls++;
    return null;
  }

  @override
  Future<int?> discardProfiler(SentryId traceId) {
    numberOfDiscardProfilerCalls++;
    return Future.value(null);
  }

  @override
  Future<void> init(SentryFlutterOptions options) {
    numberOfInitCalls++;
    return Future.value(null);
  }

  @override
  Future<void> close() {
    numberOfCloseCalls++;
    return Future.value(null);
  }
}

class MockRendererWrapper implements RendererWrapper {
  MockRendererWrapper(this._renderer);

  final FlutterRenderer? _renderer;

  @override
  FlutterRenderer? getRenderer() {
    return _renderer;
  }
}

class TestBindingWrapper implements BindingWrapper {
  bool ensureBindingInitializedCalled = false;
  bool getWidgetsBindingInstanceCalled = false;

  @override
  WidgetsBinding ensureInitialized() {
    ensureBindingInitializedCalled = true;
    return TestWidgetsFlutterBinding.ensureInitialized();
  }

  @override
  WidgetsBinding get instance {
    getWidgetsBindingInstanceCalled = true;
    return TestWidgetsFlutterBinding.instance;
  }
}

class MockSentryClient with NoSuchMethodProvider implements SentryClient {}
