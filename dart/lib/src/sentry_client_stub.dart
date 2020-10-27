// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'sentry_client.dart';
import 'sentry_options.dart';

/// Implemented in `sentry_browser_client.dart` and `sentry_io_client.dart`.
SentryClient createSentryClient(SentryOptions options) =>
    throw UnsupportedError(
        'Cannot create a client without dart:html or dart:io.');
