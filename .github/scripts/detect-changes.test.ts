import assert from 'node:assert/strict';
import { test } from 'node:test';

import { detectChanges } from './detect-changes.ts';

// Builds dorny/paths-filter outputs (list-files: json) for the given matches.
function filterOutputs(changed: string[], matches: Record<string, string[]> = {}) {
  const outputs: Record<string, string> = { ci_changed_files: JSON.stringify(changed) };
  for (const [filter, files] of Object.entries(matches)) {
    outputs[`ci_${filter}_files`] = JSON.stringify(files);
  }
  return outputs;
}

function run(eventName: string, outputs: Record<string, string>) {
  const result: Record<string, string> = {};
  detectChanges({
    core: { info() {}, setOutput: (name, value) => (result[name] = value) },
    eventName,
    filterOutputs: outputs,
  });
  return result;
}

const EVERYTHING = {
  shared: 'true',
  android: 'true',
  cocoa: 'true',
  desktop: 'true',
  web: 'true',
  flutter_targets: '["android","ios","macos","linux","windows","js","wasm"]',
};

test('push runs everything without filter outputs', () => {
  assert.deepEqual(run('push', {}), EVERYTHING);
});

test('Dart change runs everything', () => {
  const file = 'packages/flutter/lib/src/sentry_flutter.dart';
  assert.deepEqual(run('pull_request', filterOutputs([file])), EVERYTHING);
});

test('Android-only change runs only Android', () => {
  const file = 'packages/flutter/android/build.gradle';
  assert.deepEqual(run('pull_request', filterOutputs([file], { android: [file] })), {
    shared: 'false',
    android: 'true',
    cocoa: 'false',
    desktop: 'false',
    web: 'false',
    flutter_targets: '["android"]',
  });
});

test('Cocoa and desktop changes run both platforms', () => {
  const darwin = 'packages/flutter/darwin/sentry_flutter/Package.swift';
  const linux = 'packages/flutter/linux/CMakeLists.txt';
  const outputs = filterOutputs([darwin, linux], { cocoa: [darwin], desktop: [linux] });
  assert.deepEqual(run('pull_request', outputs), {
    shared: 'false',
    android: 'false',
    cocoa: 'true',
    desktop: 'true',
    web: 'false',
    flutter_targets: '["ios","macos","linux","windows"]',
  });
});

test('native change with an unmatched file runs everything', () => {
  const gradle = 'packages/flutter/android/build.gradle';
  const script = 'packages/flutter/scripts/update-android.sh';
  const outputs = filterOutputs([gradle, script], { android: [gradle] });
  assert.deepEqual(run('pull_request', outputs), EVERYTHING);
});

test('ignored file inside a platform folder runs nothing', () => {
  const file = 'packages/flutter/example/ios/Gemfile.lock';
  assert.deepEqual(run('pull_request', filterOutputs([file], { ignored: [file], cocoa: [file] })), {
    shared: 'false',
    android: 'false',
    cocoa: 'false',
    desktop: 'false',
    web: 'false',
    flutter_targets: '[]',
  });
});
