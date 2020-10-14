// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'utils.dart';

/// Implemented in `browser_client.dart` and `io_client.dart`.
SentryClient createSentryClient({
  @required String dsn,
  Event environment,
  bool compressPayload,
  Client httpClient,
  dynamic clock,
  UuidGenerator uuidGenerator,
}) =>
    throw UnsupportedError(
        'Cannot create a client without dart:html or dart:io.');
