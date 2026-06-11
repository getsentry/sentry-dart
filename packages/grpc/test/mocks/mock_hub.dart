import 'package:sentry/sentry.dart';

import '../mocks.dart';
import 'no_such_method_provider.dart';

class MockHub with NoSuchMethodProvider implements Hub {
  List<CaptureExceptionCall> captureExceptionCalls = [];
  List<AddBreadcrumbCall> addBreadcrumbCalls = [];
  int closeCalls = 0;
  bool _isEnabled = true;

  @override
  Scope get scope => Scope(_options);

  final _options = defaultTestOptions();

  @override
  // ignore: invalid_use_of_internal_member
  SentryOptions get options => _options;

  void reset() {
    captureExceptionCalls = [];
    addBreadcrumbCalls = [];
    closeCalls = 0;
    _isEnabled = true;
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    addBreadcrumbCalls.add(AddBreadcrumbCall(crumb, hint));
  }

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Hint? hint,
    SentryMessage? message,
    ScopeCallback? withScope,
  }) async {
    captureExceptionCalls
        .add(CaptureExceptionCall(throwable, stackTrace, hint));
    return SentryId.newId();
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _isEnabled = false;
  }

  @override
  bool get isEnabled => _isEnabled;

  @override
  ISentrySpan? getSpan() => null;
}

class CaptureExceptionCall {
  final dynamic throwable;
  final dynamic stackTrace;
  final Hint? hint;

  CaptureExceptionCall(this.throwable, this.stackTrace, this.hint);
}

class AddBreadcrumbCall {
  final Breadcrumb crumb;
  final Hint? hint;

  AddBreadcrumbCall(this.crumb, this.hint);
}
