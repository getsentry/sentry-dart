// Mocks generated by Mockito 5.4.2 from annotations
// in sentry/test/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:mockito/mockito.dart' as _i1;
import 'package:sentry/sentry.dart' as _i3;
import 'package:sentry/src/profiling.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeProfiler_0 extends _i1.SmartFake implements _i2.Profiler {
  _FakeProfiler_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeProfileInfo_1 extends _i1.SmartFake implements _i2.ProfileInfo {
  _FakeProfileInfo_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryEnvelopeItem_2 extends _i1.SmartFake
    implements _i3.SentryEnvelopeItem {
  _FakeSentryEnvelopeItem_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [ProfilerFactory].
///
/// See the documentation for Mockito's code generation for more information.
class MockProfilerFactory extends _i1.Mock implements _i2.ProfilerFactory {
  MockProfilerFactory() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.Profiler startProfiling(_i3.SentryTransactionContext? context) =>
      (super.noSuchMethod(
        Invocation.method(
          #startProfiling,
          [context],
        ),
        returnValue: _FakeProfiler_0(
          this,
          Invocation.method(
            #startProfiling,
            [context],
          ),
        ),
      ) as _i2.Profiler);
}

/// A class which mocks [Profiler].
///
/// See the documentation for Mockito's code generation for more information.
class MockProfiler extends _i1.Mock implements _i2.Profiler {
  MockProfiler() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<_i2.ProfileInfo> finishFor(_i3.SentryTransaction? transaction) =>
      (super.noSuchMethod(
        Invocation.method(
          #finishFor,
          [transaction],
        ),
        returnValue: _i4.Future<_i2.ProfileInfo>.value(_FakeProfileInfo_1(
          this,
          Invocation.method(
            #finishFor,
            [transaction],
          ),
        )),
      ) as _i4.Future<_i2.ProfileInfo>);
  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [ProfileInfo].
///
/// See the documentation for Mockito's code generation for more information.
class MockProfileInfo extends _i1.Mock implements _i2.ProfileInfo {
  MockProfileInfo() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.FutureOr<_i3.SentryEnvelopeItem> asEnvelopeItem() => (super.noSuchMethod(
        Invocation.method(
          #asEnvelopeItem,
          [],
        ),
        returnValue:
            _i4.Future<_i3.SentryEnvelopeItem>.value(_FakeSentryEnvelopeItem_2(
          this,
          Invocation.method(
            #asEnvelopeItem,
            [],
          ),
        )),
      ) as _i4.FutureOr<_i3.SentryEnvelopeItem>);
}
