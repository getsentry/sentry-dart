// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sentry.io has a concept of "SDK", which refers to the client library or
/// tool used to submit events to Sentry.io.
///
/// This library contains Sentry.io SDK constants used by this package.
library version;

import 'utils.dart';

/// The SDK version reported to Sentry.io in the submitted events.
const String sdkVersion = '4.0.0';

String get sdkName => isWeb ? browserSdkName : ioSdkName;

/// The default SDK name reported to Sentry.io in the submitted events.
const String ioSdkName = 'sentry.dart';

/// The SDK name for web projects reported to Sentry.io in the submitted events.
const String browserSdkName = 'sentry.dart.browser';

/// The name of the SDK platform reported to Sentry.io in the submitted events.
///
/// Used for IO version.
const String sdkPlatform = 'dart';

/// Used to report browser Stacktrace to sentry.
const String browserPlatform = 'javascript';
