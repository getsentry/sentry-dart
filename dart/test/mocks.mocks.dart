// Mocks generated by Mockito 5.4.5 from annotations
// in sentry/test/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:mockito/mockito.dart' as _i1;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSentryEnvelopeItem_0 extends _i1.SmartFake
    implements _i2.SentryEnvelopeItem {
  _FakeSentryEnvelopeItem_0(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

/// A class which mocks [SentryProfilerFactory].
///
/// See the documentation for Mockito's code generation for more information.
class MockSentryProfilerFactory extends _i1.Mock
    implements _i3.SentryProfilerFactory {
  MockSentryProfilerFactory() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.SentryProfiler? startProfiler(_i2.SentryTransactionContext? context) =>
      (super.noSuchMethod(Invocation.method(#startProfiler, [context]))
          as _i3.SentryProfiler?);
}

/// A class which mocks [SentryProfiler].
///
/// See the documentation for Mockito's code generation for more information.
class MockSentryProfiler extends _i1.Mock implements _i3.SentryProfiler {
  MockSentryProfiler() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<_i3.SentryProfileInfo?> finishFor(
    _i2.SentryTransaction? transaction,
  ) =>
      (super.noSuchMethod(
        Invocation.method(#finishFor, [transaction]),
        returnValue: _i4.Future<_i3.SentryProfileInfo?>.value(),
      ) as _i4.Future<_i3.SentryProfileInfo?>);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(#dispose, []),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [SentryProfileInfo].
///
/// See the documentation for Mockito's code generation for more information.
class MockSentryProfileInfo extends _i1.Mock implements _i3.SentryProfileInfo {
  MockSentryProfileInfo() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.SentryEnvelopeItem asEnvelopeItem() => (super.noSuchMethod(
        Invocation.method(#asEnvelopeItem, []),
        returnValue: _FakeSentryEnvelopeItem_0(
          this,
          Invocation.method(#asEnvelopeItem, []),
        ),
      ) as _i2.SentryEnvelopeItem);
}

/// A class which mocks [ExceptionTypeIdentifier].
///
/// See the documentation for Mockito's code generation for more information.
class MockExceptionTypeIdentifier extends _i1.Mock
    implements _i2.ExceptionTypeIdentifier {
  MockExceptionTypeIdentifier() {
    _i1.throwOnMissingStub(this);
  }
}
