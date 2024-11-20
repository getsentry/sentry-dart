// ignore_for_file: deprecated_member_use_from_same_package

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_scope_observer.dart';
import 'test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('sets $SentryLevel', () {
    final sut = fixture.getSut();

    sut.level = SentryLevel.debug;

    expect(sut.level, SentryLevel.debug);
  });

  test('sets transaction', () {
    final sut = fixture.getSut();

    sut.transaction = 'test';

    expect(sut.transaction, 'test');
  });

  test('sets transaction overwrites span name', () {
    final sut = fixture.getSut();

    sut.span = fixture.sentryTracer;
    sut.transaction = 'test';

    expect(sut.transaction, 'test');
    expect((sut.span as SentryTracer).name, 'test');
  });

  test('sets span overwrites transaction name', () {
    final sut = fixture.getSut();

    sut.span = fixture.sentryTracer;

    expect(sut.transaction, 'name');
    expect((sut.span as SentryTracer).name, 'name');
  });

  test('removing span resets transaction if not set separately', () {
    final sut = fixture.getSut();

    sut.span = fixture.sentryTracer;
    sut.span = null;

    expect(sut.transaction, isNull);
  });

  test('removing span does not reset transaction if set separately', () {
    final sut = fixture.getSut();

    sut.transaction = 'test';
    sut.span = fixture.sentryTracer;
    sut.span = null;

    expect(sut.transaction, 'test');
  });

  test('sets $SentryUser', () {
    final sut = fixture.getSut();

    final user = SentryUser(id: 'test');
    sut.setUser(user);

    expect(sut.user, user);
  });

  test('sets fingerprint', () {
    final sut = fixture.getSut();

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    expect(sut.fingerprint, fingerprints);
  });

  test('sets replay ID', () {
    final sut = fixture.getSut();

    sut.replayId = SentryId.fromId('1');

    expect(sut.replayId, SentryId.fromId('1'));
  });

  test('adds $Breadcrumb', () {
    final sut = fixture.getSut();

    final breadcrumb = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.last, breadcrumb);
  });

  test('beforeBreadcrumb called with user provided hint', () {
    Hint? actual;
    BeforeBreadcrumbCallback bb = (_, hint) {
      actual = hint;
      return null;
    };
    final sut = fixture.getSut(
      beforeBreadcrumbCallback: bb,
    );

    final breadcrumb = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final hint = Hint.withMap({'user-name': 'joe dirt'});
    sut.addBreadcrumb(breadcrumb, hint: hint);

    expect(actual?.get('user-name'), 'joe dirt');
  });

  test('Executes and drops $Breadcrumb', () {
    final sut = fixture.getSut(
      beforeBreadcrumbCallback: fixture.beforeBreadcrumbCallback,
    );

    final breadcrumb = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.length, 0);
  });

  test('Executes and mutates $Breadcrumb', () {
    final sut = fixture.getSut(
      beforeBreadcrumbCallback: fixture.beforeBreadcrumbMutateCallback,
    );

    final breadcrumb = Breadcrumb(
      message: 'message',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.first.message, 'new message');
  });

  test('adds $EventProcessor', () {
    final sut = fixture.getSut();

    sut.addEventProcessor(fixture.processor);

    expect(sut.eventProcessors.last, isA<DropAllEventProcessor>());
  });

  test('respects max $Breadcrumb', () {
    final maxBreadcrumbs = 2;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb2 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb3 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('rotates $Breadcrumb', () {
    final sut = fixture.getSut(maxBreadcrumbs: 2);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb2 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    final breadcrumb3 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.first, breadcrumb2);

    expect(sut.breadcrumbs.last, breadcrumb3);
  });

  test('empty $Breadcrumb list', () {
    final maxBreadcrumbs = 0;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('clears $Breadcrumb list', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);
    sut.clear();

    expect(sut.breadcrumbs.length, 0);
  });

  test('adds $SentryAttachment', () {
    final sut = fixture.getSut();

    final attachment = SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt');
    sut.addAttachment(attachment);

    expect(sut.attachments.last, attachment);
    expect(sut.attachments.length, 1);
  });

  test('clear() removes all $SentryAttachment', () {
    final sut = fixture.getSut();

    final attachment = SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt');
    sut.addAttachment(attachment);
    expect(sut.attachments.length, 1);
    sut.clear();

    expect(sut.attachments.length, 0);
  });

  test('clearAttachments() removes all $SentryAttachment', () {
    final sut = fixture.getSut();

    final attachment = SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt');
    sut.addAttachment(attachment);
    expect(sut.attachments.length, 1);
    sut.clearAttachments();

    expect(sut.attachments.length, 0);
  });

  test('sets tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');

    expect(sut.tags['test'], 'test');
  });

  test('removes tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.removeTag('test');

    expect(sut.tags['test'], null);
  });

  test('sets extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');

    expect(sut.extra['test'], 'test');
  });

  test('removes extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');
    sut.removeExtra('test');

    expect(sut.extra['test'], null);
  });

  test('clears $Scope', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    );
    sut.addBreadcrumb(breadcrumb1);

    sut.level = SentryLevel.debug;
    sut.transaction = 'test';
    sut.span = null;
    sut.replayId = SentryId.newId();

    final user = SentryUser(id: 'test');
    sut.setUser(user);

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    sut.setTag('test', 'test');
    sut.setExtra('test', 'test');

    sut.addEventProcessor(fixture.processor);

    sut.clear();

    expect(sut.breadcrumbs.length, 0);
    expect(sut.level, null);
    expect(sut.transaction, null);
    expect(sut.span, null);
    expect(sut.user, null);
    expect(sut.fingerprint.length, 0);
    expect(sut.tags.length, 0);
    expect(sut.extra.length, 0);
    expect(sut.eventProcessors.length, 0);
    expect(sut.replayId, isNull);
  });

  test('clones', () async {
    final sut = fixture.getSut();

    await sut.addBreadcrumb(Breadcrumb(
      message: 'test log',
      timestamp: DateTime.utc(2019),
    ));
    sut.addAttachment(SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt'));
    sut.span = NoOpSentrySpan();
    sut.level = SentryLevel.warning;
    sut.replayId = SentryId.newId();
    await sut.setUser(SentryUser(id: 'id'));
    await sut.setTag('key', 'vakye');
    await sut.setExtra('key', 'vakye');
    sut.transaction = 'transaction';

    final clone = sut.clone();
    expect(sut.user, clone.user);
    expect(sut.transaction, clone.transaction);
    expect(sut.extra, clone.extra);
    expect(sut.tags, clone.tags);
    expect(sut.breadcrumbs, clone.breadcrumbs);
    expect(sut.contexts, clone.contexts);
    expect(sut.attachments, clone.attachments);
    expect(sut.level, clone.level);
    expect(ListEquality().equals(sut.fingerprint, clone.fingerprint), true);
    expect(
      ListEquality().equals(sut.eventProcessors, clone.eventProcessors),
      true,
    );
    expect(sut.span, clone.span);
    expect(sut.replayId, clone.replayId);
  });

  test('clone does not additionally call observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);

    await sut.setContexts("fixture-contexts-key", "fixture-contexts-value");
    await sut.removeContexts("fixture-contexts-key");
    await sut.setUser(SentryUser(username: "fixture-username"));
    await sut.addBreadcrumb(Breadcrumb());
    await sut.clearBreadcrumbs();
    await sut.setExtra("fixture-extra-key", "fixture-extra-value");
    await sut.removeExtra("fixture-extra-key");
    await sut.setTag("fixture-tag-key", "fixture-tag-value");
    await sut.removeTag("fixture-tag-key");

    sut.clone();

    expect(1, fixture.mockScopeObserver.numberOfSetContextsCalls);
    expect(1, fixture.mockScopeObserver.numberOfRemoveContextsCalls);
    expect(1, fixture.mockScopeObserver.numberOfSetUserCalls);
    expect(1, fixture.mockScopeObserver.numberOfAddBreadcrumbCalls);
    expect(1, fixture.mockScopeObserver.numberOfClearBreadcrumbsCalls);
    expect(1, fixture.mockScopeObserver.numberOfSetExtraCalls);
    expect(1, fixture.mockScopeObserver.numberOfRemoveExtraCalls);
    expect(1, fixture.mockScopeObserver.numberOfSetTagCalls);
    expect(1, fixture.mockScopeObserver.numberOfRemoveTagCalls);
  });

  test('clone has disabled scope sync', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    final clone = sut.clone();

    await clone.setContexts("fixture-contexts-key", "fixture-contexts-value");
    expect(0, fixture.mockScopeObserver.numberOfSetContextsCalls);
  });

  group('Scope apply', () {
    final scopeUser = SentryUser(
      id: '800',
      username: 'first-user',
      email: 'first@user.lan',
      ipAddress: '127.0.0.1',
      data: const <String, String>{'first-sign-in': '2020-01-01'},
    );

    final breadcrumb = Breadcrumb(message: 'Authenticated');

    test('apply context to event', () async {
      final event = SentryEvent(
        tags: const {'etag': '987'},
        extra: const {'e-infos': 'abc'},
      );
      final scope = Scope(defaultTestOptions())
        ..fingerprint = ['example-dart']
        ..transaction = '/example/app'
        ..level = SentryLevel.warning
        ..addEventProcessor(AddTagsEventProcessor({'page-locale': 'en-us'}));

      await scope.addBreadcrumb(breadcrumb);
      await scope.setTag('build', '579');
      await scope.setExtra('company-name', 'Dart Inc');
      await scope.setContexts('theme', 'material');
      await scope.setUser(scopeUser);

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.user, scopeUser);
      expect(updatedEvent?.transaction, '/example/app');
      expect(updatedEvent?.fingerprint, ['example-dart']);
      expect(updatedEvent?.breadcrumbs, [breadcrumb]);
      expect(updatedEvent?.level, SentryLevel.warning);
      expect(updatedEvent?.tags,
          {'etag': '987', 'build': '579', 'page-locale': 'en-us'});
      expect(
          updatedEvent?.extra, {'e-infos': 'abc', 'company-name': 'Dart Inc'});
      expect(updatedEvent?.contexts['theme'], {'value': 'material'});
    });

    test('apply trace context to event', () async {
      final event = SentryEvent();
      final scope = Scope(defaultTestOptions())..span = fixture.sentryTracer;

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.contexts['trace'] is SentryTraceContext, true);
    });

    test('should not apply the scope properties when event already has it ',
        () async {
      final eventUser = SentryUser(id: '123');
      final eventBreadcrumb = Breadcrumb(message: 'event-breadcrumb');

      final event = SentryEvent(
        transaction: '/event/transaction',
        user: eventUser,
        fingerprint: ['event-fingerprint'],
        breadcrumbs: [eventBreadcrumb],
      );
      final scope = Scope(defaultTestOptions())
        ..fingerprint = ['example-dart']
        ..transaction = '/example/app';

      await scope.addBreadcrumb(breadcrumb);
      await scope.setUser(scopeUser);

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.user, isNotNull);
      expect(updatedEvent?.user?.id, eventUser.id);
      expect(updatedEvent?.transaction, '/event/transaction');
      expect(updatedEvent?.fingerprint, ['event-fingerprint']);
      expect(updatedEvent?.breadcrumbs, [eventBreadcrumb]);
    });

    test(
        'should not apply the scope.contexts values if the event already has it',
        () async {
      final event = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(name: 'event-device'),
          app: SentryApp(name: 'event-app'),
          gpu: SentryGpu(name: 'event-gpu'),
          runtimes: [SentryRuntime(name: 'event-runtime')],
          browser: SentryBrowser(name: 'event-browser'),
          operatingSystem: SentryOperatingSystem(name: 'event-os'),
        ),
      );
      final scope = Scope(defaultTestOptions());
      await scope.setContexts(
        SentryDevice.type,
        SentryDevice(name: 'context-device'),
      );
      await scope.setContexts(
        SentryApp.type,
        SentryApp(name: 'context-app'),
      );
      await scope.setContexts(
        SentryGpu.type,
        SentryGpu(name: 'context-gpu'),
      );
      await scope.setContexts(
        SentryRuntime.listType,
        [SentryRuntime(name: 'context-runtime')],
      );
      await scope.setContexts(
        SentryBrowser.type,
        SentryBrowser(name: 'context-browser'),
      );
      await scope.setContexts(
        SentryOperatingSystem.type,
        SentryOperatingSystem(name: 'context-os'),
      );

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.contexts[SentryDevice.type].name, 'event-device');
      expect(updatedEvent?.contexts[SentryApp.type].name, 'event-app');
      expect(updatedEvent?.contexts[SentryGpu.type].name, 'event-gpu');
      expect(updatedEvent?.contexts[SentryRuntime.listType].first.name,
          'event-runtime');
      expect(updatedEvent?.contexts[SentryBrowser.type].name, 'event-browser');
      expect(
          updatedEvent?.contexts[SentryOperatingSystem.type].name, 'event-os');
    });

    test('should apply the scope.contexts values', () async {
      final event = SentryEvent();
      final scope = Scope(defaultTestOptions());
      await scope.setContexts(
          SentryDevice.type, SentryDevice(name: 'context-device'));
      await scope.setContexts(SentryApp.type, SentryApp(name: 'context-app'));
      await scope.setContexts(SentryGpu.type, SentryGpu(name: 'context-gpu'));
      await scope.setContexts(
          SentryRuntime.listType, [SentryRuntime(name: 'context-runtime')]);
      await scope.setContexts(
          SentryBrowser.type, SentryBrowser(name: 'context-browser'));
      await scope.setContexts(SentryOperatingSystem.type,
          SentryOperatingSystem(name: 'context-os'));
      await scope.setContexts('theme', 'material');
      await scope.setContexts('version', 9);
      await scope.setContexts('location', {'city': 'London'});
      await scope.setContexts('items', [1, 2, 3]);

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.contexts[SentryDevice.type].name, 'context-device');
      expect(updatedEvent?.contexts[SentryApp.type].name, 'context-app');
      expect(updatedEvent?.contexts[SentryGpu.type].name, 'context-gpu');
      expect(
        updatedEvent?.contexts[SentryRuntime.listType].first.name,
        'context-runtime',
      );
      expect(
          updatedEvent?.contexts[SentryBrowser.type].name, 'context-browser');
      expect(updatedEvent?.contexts[SentryOperatingSystem.type].name,
          'context-os');
      expect(updatedEvent?.contexts['theme']['value'], 'material');
      expect(updatedEvent?.contexts['version']['value'], 9);
      expect(updatedEvent?.contexts['location'], {'city': 'London'});
      final items = updatedEvent?.contexts['items'];
      expect(items['value'], [1, 2, 3]);
    });

    test('should apply the scope level', () async {
      final event = SentryEvent(level: SentryLevel.warning);
      final scope = Scope(defaultTestOptions())..level = SentryLevel.error;

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.level, SentryLevel.error);
    });

    test('should apply the scope transaction from the span', () async {
      final event = SentryEvent();
      final scope = Scope(defaultTestOptions())..span = fixture.sentryTracer;

      final updatedEvent = await scope.applyToEvent(event, Hint());

      expect(updatedEvent?.transaction, 'name');
    });
  });

  test('event processor drops the event', () async {
    final sut = fixture.getSut();

    sut.addEventProcessor(fixture.processor);

    final event = SentryEvent();
    var newEvent = await sut.applyToEvent(event, Hint());

    expect(newEvent, isNull);
  });

  test('should not apply fingerprint if transaction', () async {
    var tr = SentryTransaction(fixture.sentryTracer);
    final scope = Scope(defaultTestOptions())..fingerprint = ['test'];

    final updatedTr = await scope.applyToEvent(tr, Hint());

    expect(updatedTr?.fingerprint, isNull);
  });

  test('should not apply level if transaction', () async {
    var tr = SentryTransaction(fixture.sentryTracer);
    final scope = Scope(defaultTestOptions())..level = SentryLevel.error;

    final updatedTr = await scope.applyToEvent(tr, Hint());

    expect(updatedTr?.level, isNull);
  });

  test('apply sampled to trace', () async {
    var tr = SentryTransaction(fixture.sentryTracer);
    final scope = Scope(defaultTestOptions())..level = SentryLevel.error;

    final updatedTr = await scope.applyToEvent(tr, Hint());

    expect(updatedTr?.contexts.trace?.sampled, isTrue);
  });

  test('addBreadcrumb should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.addBreadcrumb(Breadcrumb());

    expect(true, fixture.mockScopeObserver.calledAddBreadcrumb);
  });

  test('addBreadcrumb passes processed breadcrumb to scope observers',
      () async {
    final sut = fixture.getSut(
      scopeObserver: fixture.mockScopeObserver,
      beforeBreadcrumbCallback: (
        Breadcrumb? breadcrumb,
        Hint hint,
      ) {
        return breadcrumb?.copyWith(message: "modified");
      },
    );
    await sut.addBreadcrumb(Breadcrumb());

    expect(fixture.mockScopeObserver.addedBreadcrumbs[0].message, "modified");
  });

  test('clearBreadcrumbs should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.clearBreadcrumbs();

    expect(true, fixture.mockScopeObserver.calledClearBreadcrumbs);
  });

  test('removeContexts should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.removeContexts('fixture-key');

    expect(true, fixture.mockScopeObserver.calledRemoveContexts);
  });

  test('removeExtra should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.removeExtra('fixture-key');

    expect(true, fixture.mockScopeObserver.calledRemoveExtra);
  });

  test('removeTag should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.removeTag('fixture-key');

    expect(true, fixture.mockScopeObserver.calledRemoveTag);
  });

  test('setContexts should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.setContexts('fixture-key', 'fixture-value');

    expect(true, fixture.mockScopeObserver.calledSetContexts);
  });

  test('setExtra should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.setExtra('fixture-key', 'fixture-value');

    expect(true, fixture.mockScopeObserver.calledSetExtra);
  });

  test('setTag should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.setTag('fixture-key', 'fixture-value');

    expect(true, fixture.mockScopeObserver.calledSetTag);
  });

  test('setUser should call scope observers', () async {
    final sut = fixture.getSut(scopeObserver: fixture.mockScopeObserver);
    await sut.setUser(null);

    expect(true, fixture.mockScopeObserver.calledSetUser);
  });

  group("Scope exceptions", () {
    test("addBreadcrumb with beforeBreadcrumb error handled ", () async {
      final exception = Exception("before breadcrumb exception");

      fixture.options.automatedTestMode = false;
      final sut = fixture.getSut(
          beforeBreadcrumbCallback: (
            Breadcrumb? breadcrumb,
            Hint hint,
          ) {
            throw exception;
          },
          debug: true);

      final breadcrumb = Breadcrumb(
        message: 'test log',
        timestamp: DateTime.utc(2019),
      );

      await sut.addBreadcrumb(breadcrumb);

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
    });

    test("clone with beforeBreadcrumb error handled ", () async {
      var numberOfBeforeBreadcrumbCalls = 0;
      final exception = Exception("before breadcrumb exception");

      fixture.options.automatedTestMode = false;
      final sut = fixture.getSut(
          beforeBreadcrumbCallback: (
            Breadcrumb? breadcrumb,
            Hint hint,
          ) {
            if (numberOfBeforeBreadcrumbCalls > 0) {
              throw exception;
            }
            numberOfBeforeBreadcrumbCalls += 1;
            return breadcrumb;
          },
          debug: true);

      final breadcrumb = Breadcrumb(
        message: 'test log',
        timestamp: DateTime.utc(2019),
      );
      await sut.addBreadcrumb(breadcrumb);
      sut.clone();

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
    });
  });

  // addBreadcrumb
  // clone
}

class Fixture {
  final mockScopeObserver = MockScopeObserver();

  final options = defaultTestOptions();

  final sentryTracer = SentryTracer(
    SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(true),
    ),
    MockHub(),
  );

  SentryLevel? loggedLevel;
  Object? loggedException;

  Scope getSut({
    int maxBreadcrumbs = 100,
    BeforeBreadcrumbCallback? beforeBreadcrumbCallback,
    ScopeObserver? scopeObserver,
    bool debug = false,
  }) {
    options.maxBreadcrumbs = maxBreadcrumbs;
    options.beforeBreadcrumb = beforeBreadcrumbCallback;
    options.debug = debug;
    options.logger = mockLogger;

    if (scopeObserver != null) {
      options.addScopeObserver(scopeObserver);
    }
    return Scope(options);
  }

  EventProcessor get processor => DropAllEventProcessor();

  Breadcrumb? beforeBreadcrumbCallback(Breadcrumb? breadcrumb, Hint hint) =>
      null;

  Breadcrumb? beforeBreadcrumbMutateCallback(
          Breadcrumb? breadcrumb, Hint hint) =>
      breadcrumb?.copyWith(message: 'new message');

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedException = exception;
  }
}

class AddTagsEventProcessor implements EventProcessor {
  final Map<String, String> tags;

  AddTagsEventProcessor(this.tags);

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return event..tags?.addAll(tags);
  }
}
