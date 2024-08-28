// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
library sentry_dart;

export 'src/run_zoned_guarded_integration.dart';
export 'src/hub.dart';
// useful for tests
export 'src/hub_adapter.dart';
export 'src/platform_checker.dart';
export 'src/noop_isolate_error_integration.dart'
    if (dart.library.io) 'src/isolate_error_integration.dart';
export 'src/protocol.dart';
export 'src/scope.dart';
export 'src/scope_observer.dart';
export 'src/sentry.dart';
export 'src/sentry_envelope.dart';
export 'src/sentry_envelope_item.dart';
export 'src/sentry_client.dart';
export 'src/sentry_options.dart';
// useful for integrations
export 'src/throwable_mechanism.dart';
export 'src/transport/transport.dart';
export 'src/integration.dart';
export 'src/event_processor.dart';
export 'src/http_client/sentry_http_client.dart';
export 'src/http_client/sentry_http_client_error.dart';
export 'src/sentry_attachment/sentry_attachment.dart';
export 'src/sentry_user_feedback.dart';
export 'src/utils/tracing_utils.dart';
export 'src/performance_collector.dart';
// tracing
export 'src/tracing.dart';
export 'src/hint.dart';
export 'src/type_check_hint.dart';
export 'src/sentry_baggage.dart';
// exception extraction
export 'src/exception_cause_extractor.dart';
export 'src/exception_cause.dart';
export 'src/exception_stacktrace_extractor.dart';
export 'src/exception_type_identifier.dart';
// URL
// ignore: invalid_export_of_internal_element
export 'src/utils/http_sanitizer.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/url_details.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/http_header_utils.dart';
// ignore: invalid_export_of_internal_element
export 'src/sentry_trace_origins.dart';
// ignore: invalid_export_of_internal_element
export 'src/sentry_span_operations.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils.dart';
// spotlight debugging
export 'src/spotlight.dart';
// proxy
export 'src/protocol/sentry_proxy.dart';
