import 'package:jnigen/jnigen.dart';
// ignore: depend_on_referenced_packages
import 'package:logging/logging.dart';
import 'package:jnigen/src/elements/j_elements.dart' as j;

/// This file is executed by `scripts/generate-jni-bindings.sh`.
/// Pass `--test` to generate unrestricted bindings for tests into
/// `example/integration_test/jni_binding.dart`. Without it, a minimal,
/// size-conscious binding is generated into `lib/src/native/java/binding.dart`.
Future<void> main(List<String> args) async {
  final bool isTest = args.contains('--test');

  final String outputPath = isTest
      ? 'example/integration_test/jni_binding.dart'
      : 'lib/src/native/java/binding.dart';

  final List<String> classes = <String>[
    'io.sentry.android.core.SentryAndroidOptions',
    'io.sentry.android.core.SentryAndroid',
    'io.sentry.android.core.BuildConfig',
    'io.sentry.flutter.SentryFlutterPlugin',
    'io.sentry.flutter.ReplayRecorderCallbacks',
    'io.sentry.android.core.InternalSentrySdk',
    'io.sentry.ScopesAdapter',
    'io.sentry.Breadcrumb',
    'io.sentry.Sentry',
    'io.sentry.SentryOptions',
    'io.sentry.protocol.User',
    'io.sentry.protocol.SentryId',
    'io.sentry.ScopeCallback',
    'io.sentry.protocol.SdkVersion',
    'io.sentry.Scope',
    'io.sentry.android.replay.ScreenshotRecorderConfig',
    'io.sentry.android.replay.ReplayIntegration',
    'io.sentry.SentryEvent',
    'io.sentry.SentryBaseEvent',
    'io.sentry.SentryReplayEvent',
    'io.sentry.SentryReplayOptions',
    'io.sentry.Hint',
    'io.sentry.ReplayRecording',
    'io.sentry.rrweb.RRWebOptionsEvent',
    'io.sentry.SentryLevel',
    'java.net.Proxy',
    'android.graphics.Bitmap',
  ];
  // Tests may need additional classes that we don't want in release bindings.
  if (isTest) {
    classes.add('io.sentry.protocol.SentryPackage');
  }

  final List<j.Visitor> visitors = isTest
      ? <j.Visitor>[]
      : <j.Visitor>[
          FilterElementsVisitor(
            'io.sentry.flutter.SentryFlutterPlugin',
            allowedMethods: [
              'loadDebugImagesAsBytes',
              'loadContextsAsBytes',
              'getDisplayRefreshRate',
              'fetchNativeAppStartAsBytes',
              'crash',
              'setupReplay',
              'privateSentryGetReplayIntegration',
              'getApplicationContext'
            ],
            allowedFields: ['Companion'],
          ),
          FilterElementsVisitor('android.graphics.Bitmap\$Config',
              allowedFields: ['ARGB_8888']),
          FilterElementsVisitor('java.net.Proxy\$Type',
              allowedMethods: ['valueOf']),
          FilterElementsVisitor(
              'io.sentry.SentryReplayOptions\$SentryReplayQuality',
              allowedFields: ['LOW', 'MEDIUM', 'HIGH']),
          FilterElementsVisitor('io.sentry.SentryOptions\$Proxy',
              allowedMethods: [
                'setHost',
                'setPort',
                'setUser',
                'setPass',
                'setType',
              ],
              includeConstructors: true),
          FilterElementsVisitor('io.sentry.ScopeCallback',
              allowedMethods: ['run']),
          FilterElementsVisitor('io.sentry.SentryOptions\$BeforeSendCallback',
              allowedMethods: ['execute']),
          FilterElementsVisitor(
              'io.sentry.SentryOptions\$BeforeSendReplayCallback',
              allowedMethods: ['execute']),
          FilterElementsVisitor('io.sentry.Sentry\$OptionsConfiguration',
              allowedMethods: ['configure']),
          FilterElementsVisitor('io.sentry.android.core.InternalSentrySdk',
              allowedMethods: ['captureEnvelope']),
          FilterElementsVisitor('io.sentry.flutter.ReplayRecorderCallbacks',
              allowedMethods: [
                'replayStarted',
                'replayResumed',
                'replayPaused',
                'replayStopped',
                'replayReset',
                'replayConfigChanged',
              ]),
          FilterElementsVisitor('android.graphics.Bitmap', allowedMethods: [
            'getWidth',
            'getHeight',
            'createBitmap',
            'copyPixelsFromBuffer'
          ]),
          FilterElementsVisitor('io.sentry.SentryReplayEvent'),
          FilterElementsVisitor('io.sentry.SentryReplayOptions',
              allowedMethods: [
                'setQuality',
                'setSessionSampleRate',
                'setOnErrorSampleRate',
                'setTrackConfiguration',
                'setSdkVersion'
              ]),
          FilterElementsVisitor('io.sentry.SentryLevel',
              allowedMethods: ['valueOf']),
          FilterElementsVisitor('io.sentry.android.core.BuildConfig',
              allowedFields: ['VERSION_NAME']),
          FilterElementsVisitor('io.sentry.protocol.SdkVersion',
              allowedMethods: [
                'getName',
                'setName',
                'addIntegration',
                'addPackage'
              ],
              includeConstructors: true),
          FilterElementsVisitor('java.net.Proxy'),
          FilterElementsVisitor('io.sentry.rrweb.RRWebOptionsEvent',
              allowedMethods: ['getOptionsPayload']),
          FilterElementsVisitor('io.sentry.ReplayRecording',
              allowedMethods: ['getPayload']),
          FilterElementsVisitor('io.sentry.Hint',
              allowedMethods: ['getReplayRecording']),
          FilterElementsVisitor('io.sentry.SentryEvent'),
          FilterElementsVisitor('io.sentry.SentryBaseEvent',
              allowedMethods: ['getSdk', 'setTag']),
          FilterElementsVisitor('io.sentry.android.core.SentryAndroid',
              allowedMethods: ['init']),
          FilterElementsVisitor('io.sentry.protocol.SentryId',
              allowedMethods: ['toString']),
          FilterElementsVisitor('io.sentry.android.replay.ReplayIntegration',
              allowedMethods: [
                'captureReplay',
                'getReplayId',
                'onConfigurationChanged',
                'onScreenshotRecorded'
              ]),
          FilterElementsVisitor(
              'io.sentry.android.replay.ScreenshotRecorderConfig',
              includeConstructors: true),
          FilterElementsVisitor('io.sentry.Scope',
              allowedMethods: ['setContexts', 'removeContexts']),
          FilterElementsVisitor('io.sentry.protocol.User',
              allowedMethods: ['fromMap']),
          FilterElementsVisitor('io.sentry.Sentry', allowedMethods: [
            'addBreadcrumb',
            'clearBreadcrumbs',
            'setUser',
            'configureScope',
            'setTag',
            'removeTag',
            'setExtra',
            'removeExtra'
          ]),
          FilterElementsVisitor('io.sentry.Breadcrumb',
              allowedMethods: ['fromMap']),
          FilterElementsVisitor('io.sentry.ScopesAdapter',
              allowedMethods: ['getInstance', 'getOptions']),
          FilterElementsVisitor('io.sentry.SentryOptions', allowedMethods: [
            'setDsn',
            'setDebug',
            'setEnvironment',
            'setRelease',
            'setDist',
            'setEnableAutoSessionTracking',
            'setSessionTrackingIntervalMillis',
            'setAttachThreads',
            'setAttachStacktrace',
            'setEnableUserInteractionBreadcrumbs',
            'setMaxBreadcrumbs',
            'setMaxCacheItems',
            'setDiagnosticLevel',
            'setSendDefaultPii',
            'setProguardUuid',
            'setEnableSpotlight',
            'setSpotlightConnectionUrl',
            'setEnableUncaughtExceptionHandler',
            'setSendClientReports',
            'setMaxAttachmentSize',
            'setConnectionTimeoutMillis',
            'setReadTimeoutMillis',
            'setProxy',
            'setSentryClientName',
            'setBeforeSend',
            'setBeforeSendReplay',
            'getSessionReplay',
            'getSdkVersion',
          ]),
          FilterElementsVisitor('io.sentry.android.core.SentryAndroidOptions',
              allowedMethods: [
                'setAnrTimeoutIntervalMillis',
                'setAnrEnabled',
                'setEnableActivityLifecycleBreadcrumbs',
                'setEnableAppLifecycleBreadcrumbs',
                'setEnableSystemEventBreadcrumbs',
                'setEnableAppComponentBreadcrumbs',
                'setEnableScopeSync',
                'setNativeSdkName',
              ]),
        ];

  await generateJniBindings(Config(
    outputConfig: OutputConfig(
      dartConfig: DartCodeOutputConfig(
        path: Uri.parse(outputPath),
        structure: OutputStructure.singleFile,
      ),
    ),
    logLevel: Level.ALL,
    androidSdkConfig: AndroidSdkConfig(
      addGradleDeps: true,
      androidExample: 'example/',
    ),
    classes: classes,
    visitors: visitors,
  ));
}

/// Allows only selected members of a single Java class to be generated.
/// This allows us to tightly control what JNI bindings we want so the binary size
/// stays as small as possible.
///
/// - Targets one class (`classBinaryName`) and leaves others untouched.
/// - Keeps methods in [allowedMethods] and fields in [allowedFields]; excludes the rest.
/// - Constructors are excluded unless [includeConstructors] is true.
class FilterElementsVisitor extends j.Visitor {
  final String classBinaryName;
  final Set<String> allowedMethods;
  final Set<String> allowedFields;
  final bool includeConstructors;

  bool _active = false;

  FilterElementsVisitor(
    this.classBinaryName, {
    List<String>? allowedMethods,
    List<String>? allowedFields,
    bool? includeConstructors,
  })  : allowedMethods = (allowedMethods ?? const <String>[]).toSet(),
        allowedFields = (allowedFields ?? const <String>[]).toSet(),
        includeConstructors = includeConstructors ?? false;

  @override
  void visitClass(j.ClassDecl c) {
    _active = (c.binaryName == classBinaryName);
    if (_active) c.isExcluded = false;
  }

  @override
  void visitMethod(j.Method m) {
    if (!_active) return;
    if (m.isConstructor) {
      m.isExcluded = !includeConstructors; // exclude unless explicitly allowed
      return;
    }
    m.isExcluded = !allowedMethods.contains(m.originalName);
  }

  @override
  void visitField(j.Field f) {
    if (!_active) return;
    // Exclude all fields unless explicitly allowlisted.
    f.isExcluded = !allowedFields.contains(f.originalName);
  }
}
