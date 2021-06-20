// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A pure Dart client for Sentry.io crash reporting.
export 'src/default_integrations.dart';
export 'src/hub.dart';
// useful for tests
export 'src/hub_adapter.dart';
export 'src/platform_checker.dart';
export 'src/noop_isolate_error_integration.dart'
    if (dart.library.io) 'src/isolate_error_integration.dart';
export 'src/protocol.dart';
export 'src/scope.dart';
export 'src/sentry.dart';
export 'src/sentry_envelope.dart';
export 'src/sentry_client.dart';
export 'src/sentry_options.dart';
// useful for integrations
export 'src/throwable_mechanism.dart';
export 'src/transport/transport.dart';
export 'src/integration.dart';
export 'src/event_processor.dart';
export 'src/http_client/sentry_http_client.dart';
export 'src/scope_extensions/scope_extensions.dart';
