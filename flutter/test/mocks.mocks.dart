// Mocks generated by Mockito 5.0.4 from annotations
// in sentry_flutter/example/ios/.symlinks/plugins/sentry_flutter/test/mocks.dart.
// Do not manually edit this file.

import 'dart:async' as _i4;

import 'package:mockito/mockito.dart' as _i1;
import 'package:sentry/src/hub.dart' as _i3;
import 'package:sentry/src/protocol/breadcrumb.dart' as _i7;
import 'package:sentry/src/protocol/sentry_event.dart' as _i5;
import 'package:sentry/src/protocol/sentry_id.dart' as _i2;
import 'package:sentry/src/protocol/sentry_level.dart' as _i6;
import 'package:sentry/src/sentry_client.dart' as _i8;
import 'package:sentry/src/sentry_envelope.dart' as _i10;
import 'package:sentry/src/transport/transport.dart' as _i9;

// ignore_for_file: comment_references
// ignore_for_file: unnecessary_parenthesis

class _FakeSentryId extends _i1.Fake implements _i2.SentryId {}

class _FakeHub extends _i1.Fake implements _i3.Hub {}

/// A class which mocks [Hub].
///
/// See the documentation for Mockito's code generation for more information.
class MockHub extends _i1.Mock implements _i3.Hub {
  MockHub() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isEnabled =>
      (super.noSuchMethod(Invocation.getter(#isEnabled), returnValue: false)
          as bool);
  @override
  _i2.SentryId get lastEventId =>
      (super.noSuchMethod(Invocation.getter(#lastEventId),
          returnValue: _FakeSentryId()) as _i2.SentryId);
  @override
  _i4.Future<_i2.SentryId> captureEvent(_i5.SentryEvent? event,
          {dynamic stackTrace, dynamic hint}) =>
      (super.noSuchMethod(
              Invocation.method(#captureEvent, [event],
                  {#stackTrace: stackTrace, #hint: hint}),
              returnValue: Future<_i2.SentryId>.value(_FakeSentryId()))
          as _i4.Future<_i2.SentryId>);
  @override
  _i4.Future<_i2.SentryId> captureException(dynamic throwable,
          {dynamic stackTrace, dynamic hint}) =>
      (super.noSuchMethod(
              Invocation.method(#captureException, [throwable],
                  {#stackTrace: stackTrace, #hint: hint}),
              returnValue: Future<_i2.SentryId>.value(_FakeSentryId()))
          as _i4.Future<_i2.SentryId>);
  @override
  _i4.Future<_i2.SentryId> captureMessage(String? message,
          {_i6.SentryLevel? level,
          String? template,
          List<dynamic>? params,
          dynamic hint}) =>
      (super.noSuchMethod(
              Invocation.method(#captureMessage, [
                message
              ], {
                #level: level,
                #template: template,
                #params: params,
                #hint: hint
              }),
              returnValue: Future<_i2.SentryId>.value(_FakeSentryId()))
          as _i4.Future<_i2.SentryId>);
  @override
  void addBreadcrumb(_i7.Breadcrumb? crumb, {dynamic hint}) => super
      .noSuchMethod(Invocation.method(#addBreadcrumb, [crumb], {#hint: hint}),
          returnValueForMissingStub: null);
  @override
  void bindClient(_i8.SentryClient? client) =>
      super.noSuchMethod(Invocation.method(#bindClient, [client]),
          returnValueForMissingStub: null);
  @override
  _i3.Hub clone() => (super.noSuchMethod(Invocation.method(#clone, []),
      returnValue: _FakeHub()) as _i3.Hub);
  @override
  _i4.Future<void> close() => (super.noSuchMethod(Invocation.method(#close, []),
      returnValue: Future<void>.value(null),
      returnValueForMissingStub: Future.value()) as _i4.Future<void>);
  @override
  void configureScope(_i3.ScopeCallback? callback) =>
      super.noSuchMethod(Invocation.method(#configureScope, [callback]),
          returnValueForMissingStub: null);
}

/// A class which mocks [Transport].
///
/// See the documentation for Mockito's code generation for more information.
class MockTransport extends _i1.Mock implements _i9.Transport {
  MockTransport() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<_i2.SentryId> send(_i10.SentryEnvelope? envelope) =>
      (super.noSuchMethod(Invocation.method(#send, [envelope]),
              returnValue: Future<_i2.SentryId>.value(_FakeSentryId()))
          as _i4.Future<_i2.SentryId>);
}
