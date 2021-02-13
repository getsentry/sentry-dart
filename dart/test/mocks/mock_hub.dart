import 'package:sentry/sentry.dart';

class MockHub implements Hub {
  @override
  void addBreadcrumb(Breadcrumb? crumb, {dynamic hint}) {
    // TODO: implement addBreadcrumb
  }

  @override
  void bindClient(SentryClient? client) {
    // TODO: implement bindClient
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent? event, {
    dynamic stackTrace,
    dynamic hint,
  }) {
    // TODO: implement captureEvent
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureException(throwable, {stackTrace, hint}) {
    // TODO: implement captureException
    throw UnimplementedError();
  }

  @override
  Future<SentryId> captureMessage(String? message,
      {SentryLevel level = SentryLevel.info,
      String? template,
      List? params,
      hint}) {
    // TODO: implement captureMessage
    throw UnimplementedError();
  }

  @override
  Hub clone() {
    // TODO: implement clone
    throw UnimplementedError();
  }

  @override
  void close() {
    // TODO: implement close
  }

  @override
  void configureScope(callback) {
    // TODO: implement configureScope
  }

  @override
  // TODO: implement isEnabled
  bool get isEnabled => throw UnimplementedError();

  @override
  // TODO: implement lastEventId
  SentryId get lastEventId => throw UnimplementedError();
}
