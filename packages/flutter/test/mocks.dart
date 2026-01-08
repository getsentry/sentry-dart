// ignore_for_file: inference_failure_on_function_return_type

import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/platform.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/frames_tracking/sentry_delayed_frames_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';

import 'mocks.mocks.dart';
import 'no_such_method_provider.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';
const fakeProguardUuid = '3457d982-65ef-576d-a6ad-65b5f30f49a5';
final _firstFrame =
    '''Error at chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/inline/injected/webauthn-listeners.js:2:127
  at chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/inline/injected/webauthn-listeners.js:2:260
''';
final _secondFrame = '''Error at http://127.0.0.1:8080/main.dart.js:2:169
  at http://127.0.0.1:8080/main.dart.js:2:304''';
// We wanna assert that the second frame is the correct debug id match
final debugIdMap = {_firstFrame: 'whatever debug id', _secondFrame: debugId};
final debugId = '82cc8a97-04c5-5e1e-b98d-bb3e647208e6';

SentryFlutterOptions defaultTestOptions(
    {Platform? platform, RuntimeChecker? checker}) {
  return SentryFlutterOptions(
      dsn: fakeDsn, platform: platform, checker: checker)
    ..automatedTestMode = true;
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
  SentryClient,
  MethodChannel,
  SentryNativeBinding,
  SentryDelayedFramesTracker,
  BindingWrapper,
  WidgetsFlutterBinding,
  SentryJsBinding,
  TimeToDisplayTracker,
  TimeToInitialDisplayTracker,
  TimeToFullDisplayTracker,
], customMocks: [
  MockSpec<Hub>(fallbackGenerators: {#startTransaction: startTransactionShim})
])
void main() {}

class MockRuntimeChecker with NoSuchMethodProvider implements RuntimeChecker {
  MockRuntimeChecker({
    this.buildMode = MockRuntimeCheckerBuildMode.debug,
    this.isObfuscated = false,
    this.isSplitDebugInfo = false,
    this.isRoot = true,
  });

  final MockRuntimeCheckerBuildMode buildMode;
  final bool isObfuscated;
  final bool isSplitDebugInfo;
  final bool isRoot;

  @override
  bool isDebugMode() => buildMode == MockRuntimeCheckerBuildMode.debug;

  @override
  bool isProfileMode() => buildMode == MockRuntimeCheckerBuildMode.profile;

  @override
  bool isReleaseMode() => buildMode == MockRuntimeCheckerBuildMode.release;

  @override
  bool isAppObfuscated() => isObfuscated;

  @override
  bool isSplitDebugInfoBuild() => isSplitDebugInfo;

  @override
  bool get isRootZone => isRoot;
}

enum MockRuntimeCheckerBuildMode { debug, profile, release }

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

class MockRendererWrapper implements RendererWrapper {
  MockRendererWrapper(this._renderer);

  final FlutterRenderer? _renderer;

  @override
  FlutterRenderer? get renderer => _renderer;
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

// All these values are based on the fakeFrameDurations list.
// The expected total frames is also based on the span duration of 1000ms and the slow and frozen frames.
const expectedTotalFrames = 18;
const expectedFramesDelay = 722;
const expectedSlowFrames = 2;
const expectedFrozenFrames = 1;

final fakeFrameDurations = [
  Duration(milliseconds: 0),
  Duration(milliseconds: 10),
  Duration(milliseconds: 20),
  Duration(milliseconds: 40),
  Duration(milliseconds: 710),
];

@GenerateMocks([Callbacks])
abstract class Callbacks {
  Future<Object?>? methodCallHandler(String method, [dynamic arguments]);
}

class NativeChannelFixture {
  late final MethodChannel channel;
  late final Future<Object?>? Function(String method, [dynamic arguments])
      handler;
  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late final codec = StandardMethodCodec();

  NativeChannelFixture() {
    TestWidgetsFlutterBinding.ensureInitialized();
    channel = MethodChannel('test.channel', codec, _messenger);
    handler = MockCallbacks().methodCallHandler;
    when(handler('initNativeSdk', any)).thenAnswer((_) => Future.value());
    when(handler('closeNativeSdk', any)).thenAnswer((_) => Future.value());
    _messenger.setMockMethodCallHandler(
        channel, (call) => handler(call.method, call.arguments));
  }

  // Mock this call as if it was invoked by the native side.
  Future<dynamic> invokeFromNative(String method, [dynamic arguments]) async {
    final call = codec.encodeMethodCall(MethodCall(method, arguments));
    final byteData = await _messenger.handlePlatformMessage(
        channel.name, call, (ByteData? data) {});
    if (byteData != null) {
      return codec.decodeEnvelope(byteData);
    } else {
      return null;
    }
  }
}

typedef EventProcessorFunction = SentryEvent? Function(
    SentryEvent event, Hint hint);

class FunctionEventProcessor implements EventProcessor {
  FunctionEventProcessor(this.applyFunction);

  final EventProcessorFunction applyFunction;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return applyFunction(event, hint);
  }
}

class MockLogger {
  final items = <MockLogItem>[];

  void call(SentryLevel level, String message,
      {String? logger, Object? exception, StackTrace? stackTrace}) {
    items.add(MockLogItem(level, message,
        logger: logger, exception: exception, stackTrace: stackTrace));
  }

  void clear() => items.clear();
}

class MockLogItem {
  final SentryLevel level;
  final String message;
  final String? logger;
  final Object? exception;
  final StackTrace? stackTrace;

  const MockLogItem(this.level, this.message,
      {this.logger, this.exception, this.stackTrace});
}

class MockTelemetryProcessor implements TelemetryProcessor {
  final List<RecordingSentrySpanV2> addedSpans = [];
  final List<SentryLog> addedLogs = [];
  int flushCalls = 0;
  int closeCalls = 0;

  @override
  void addSpan(RecordingSentrySpanV2 span) {
    addedSpans.add(span);
  }

  @override
  void addLog(SentryLog log) {
    addedLogs.add(log);
  }

  @override
  void flush() {
    flushCalls++;
  }
}
