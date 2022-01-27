// ignore_for_file: implementation_imports, public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';

class DioEventProcessor implements EventProcessor {
  DioEventProcessor(this._options, this._maxRequestBodySize);

  final SentryOptions _options;
  final MaxRequestBodySize _maxRequestBodySize;
  late final sentryExceptionFactory = SentryExceptionFactory(
    _options,
    SentryStackTraceFactory(_options),
  );

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {dynamic hint}) {
    final dynamic dioError = event.throwable;
    if (dioError is! DioError) {
      return event;
    }

    try {
      final mechanism = Mechanism(
        type: 'DioIntegration',
        description: 'This is the inner exception of the DioError',
      );
      final throwableMechanism = ThrowableMechanism(mechanism, dioError.error);
      final exception = sentryExceptionFactory.getSentryException(
        throwableMechanism,
        stackTrace: dioError.stackTrace,
      );

      // Remove the StackTrace so the message on Sentry looks much better
      dioError.stackTrace = null;

      return event.copyWith(
        exceptions: [
          exception,
          ...?event.exceptions,
        ],
        // Don't override just parts of the original request.
        // It's all or nothing.
        request: event.request ?? _toRequest(dioError),
      );
    } catch (e, stackTrace) {
      _options.logger(
        SentryLevel.debug,
        'Could not convert DioError to SentryException',
        exception: e,
        stackTrace: stackTrace,
      );
    }
    return event;
  }

  SentryRequest? _toRequest(DioError dioError) {
    final options = dioError.requestOptions;
    // As far as I can tell there's no way to get the uri without the query part
    // so we replace it with an empty string.
    final urlWithoutQuery = options.uri.replace(query: '').toString();

    final query = options.uri.query.isEmpty ? null : options.uri.query;

    final headers = options.headers
        .map((key, dynamic value) => MapEntry(key, value?.toString() ?? ''));

    return SentryRequest(
      method: options.method,
      headers: _options.sendDefaultPii ? headers : null,
      url: urlWithoutQuery,
      queryString: query,
      cookies: _options.sendDefaultPii
          ? options.headers['Cookie']?.toString()
          : null,
      data: _getRequestData(dioError.response?.data),
    );
  }

  /// Returns the request data, if possible according to the users settings.
  /// Type checks are based on DIOs [ResponseType].
  Object? _getRequestData(dynamic data) {
    if (!_options.sendDefaultPii) {
      return null;
    }
    if (data is String) {
      if (_maxRequestBodySize.shouldAddBody(data.codeUnits.length)) {
        return data;
      }
    } else if (data is List<int>) {
      if (_maxRequestBodySize.shouldAddBody(data.length)) {
        return data;
      }
    }
    return null;
    /*
    if (data is Map<String, dynamic>) {
      // Not sure how to proceed here, as converting to bytes is potentially
      // very expensive.
      return null;
    } else if (data is ResponseBody) {
      // Body is a stream and can't be added.
    }
    */
  }
}
