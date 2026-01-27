// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
library;

// ignore: invalid_export_of_internal_element
export 'src/constants.dart';
export 'src/event_processor.dart';
export 'src/exception_cause.dart';
export 'src/exception_cause_extractor.dart';
export 'src/exception_stacktrace_extractor.dart';
export 'src/exception_type_identifier.dart';
export 'src/hint.dart';
export 'src/http_client/sentry_http_client.dart';
export 'src/http_client/sentry_http_client_error.dart';
export 'src/hub.dart';
export 'src/hub_adapter.dart';
export 'src/integration.dart';
export 'src/noop_isolate_error_integration.dart'
    if (dart.library.io) 'src/isolate_error_integration.dart';
// ignore: invalid_export_of_internal_element
export 'src/performance_collector.dart';
export 'src/protocol.dart';
export 'src/protocol/sentry_feature_flag.dart';
export 'src/protocol/sentry_feature_flags.dart';
export 'src/protocol/sentry_feedback.dart';
export 'src/protocol/sentry_proxy.dart';
export 'src/run_zoned_guarded_integration.dart';
export 'src/runtime_checker.dart';
export 'src/scope.dart';
export 'src/scope_observer.dart';
export 'src/sentry.dart';
export 'src/sentry_attachment/sentry_attachment.dart';
export 'src/sentry_baggage.dart';
// ignore: invalid_export_of_internal_element
export 'src/sentry_client.dart';
// ignore: invalid_export_of_internal_element
export 'src/sdk_lifecycle_hooks.dart';
export 'src/sentry_envelope.dart';
export 'src/sentry_envelope_item.dart';
export 'src/sentry_options.dart';
// ignore: invalid_export_of_internal_element
export 'src/sentry_trace_origins.dart';
export 'src/span_data_convention.dart';
export 'src/spotlight.dart';
export 'src/throwable_mechanism.dart';
// ignore: invalid_export_of_internal_element
export 'src/tracing.dart';
export 'src/transport/transport.dart';
export 'src/type_check_hint.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/http_header_utils.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/http_sanitizer.dart';
export 'src/utils/tracing_utils.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/url_details.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/breadcrumb_log_level.dart';
export 'src/telemetry/telemetry.dart';
// ignore: invalid_export_of_internal_element
export 'src/utils/internal_logger.dart' show SentryInternalLogger;
