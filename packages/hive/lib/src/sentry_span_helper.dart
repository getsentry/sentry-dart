// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_hive_impl.dart';

/// @nodoc
@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  late final InstrumentationSpanFactory _factory;

  /// @nodoc
  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _factory = _hub.options.spanFactory;
  }

  /// @nodoc
  @internal
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    final parentSpan = _factory.getSpan(_hub);
    final span = _factory.createSpan(
      parentSpan,
      SentryHiveImpl.dbOp,
      description: description,
    );

    span?.origin = _origin;
    span?.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    if (dbName != null) {
      span?.setData(SentryHiveImpl.dbNameKey, dbName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        SentryHiveImpl.dbSystemKey: SentryHiveImpl.dbSystem,
        if (dbName != null) SentryHiveImpl.dbNameKey: dbName,
      },
      type: 'query',
    );

    try {
      final result = await execute();
      span?.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      await span?.finish();
      await _hub.scope.addBreadcrumb(breadcrumb);
    }
  }

  /// @nodoc
  @internal
  T syncWrapInSpan<T>(
    String description,
    T Function() execute, {
    String? dbName,
  }) {
    final parentSpan = _factory.getSpan(_hub);
    final span = _factory.createSpan(
      parentSpan,
      SentryHiveImpl.dbOp,
      description: description,
    );

    span?.origin = _origin;
    span?.setData('sync', true);
    span?.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    if (dbName != null) {
      span?.setData(SentryHiveImpl.dbNameKey, dbName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        SentryHiveImpl.dbSystemKey: SentryHiveImpl.dbSystem,
        if (dbName != null) SentryHiveImpl.dbNameKey: dbName,
      },
      type: 'query',
    );

    try {
      final result = execute();
      span?.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      unawaited(span?.finish());
      _hub.scope.addBreadcrumb(breadcrumb);
    }
  }
}
