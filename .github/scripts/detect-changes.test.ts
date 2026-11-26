import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { matchesGlob } from 'node:path';
import { test } from 'node:test';

import { detectChanges } from './detect-changes.ts';

// Reads the `ci_*` filters from .github/file-filters.yml. The file only uses
// `name:` keys with quoted list items, so a line parser is enough.
function readFilters(): Record<string, string[]> {
  const filters: Record<string, string[]> = {};
  let current: string[] | undefined;
  const text = readFileSync(new URL('../file-filters.yml', import.meta.url), 'utf8');
  for (const line of text.split('\n')) {
    const key = /^(ci_\w+):/.exec(line);
    if (key) {
      current = filters[key[1]] = [];
    } else if (/^\S/.test(line)) {
      current = undefined;
    } else {
      const item = /^\s+- ["'](.+)["']\s*$/.exec(line);
      if (item && current) current.push(item[1]);
    }
  }
  return filters;
}

const FILTERS = readFilters();

// Builds dorny/paths-filter outputs (list-files: json) for a PR's changed files
// from the real filters. `ci_changed` ("**") lists every file, as dorny does
// with dot: true. node's matchesGlob does not match dotfiles for the other
// filters, so the cases below avoid dot segments inside platform folders.
function filterOutputs(changed: string[]) {
  const outputs: Record<string, string> = {};
  for (const [filter, patterns] of Object.entries(FILTERS)) {
    const files =
      filter === 'ci_changed'
        ? changed
        : changed.filter((file) => patterns.some((pattern) => matchesGlob(file, pattern)));
    outputs[`${filter}_files`] = JSON.stringify(files);
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

// Expected sentry-flutter build matrix for the given targets.
function flutterMatrix(...targets: [string, string][]) {
  return JSON.stringify({
    target: targets.map(([target]) => target),
    include: targets.map(([target, platform]) => ({ target, platform })),
  });
}

const EVERYTHING = {
  shared: 'true',
  pana: 'true',
  android: 'true',
  cocoa: 'true',
  desktop: 'true',
  web: 'true',
  flutter_matrix: flutterMatrix(
    ['android', 'Android'],
    ['ios', 'iOS'],
    ['macos', 'macOS'],
    ['linux', 'Linux'],
    ['windows', 'Windows'],
    ['js', 'Web'],
    ['wasm', 'Wasm'],
  ),
};

const NOTHING = {
  shared: 'false',
  pana: 'false',
  android: 'false',
  cocoa: 'false',
  desktop: 'false',
  web: 'false',
  flutter_matrix: flutterMatrix(),
};

test('push runs everything without filter outputs', () => {
  assert.deepEqual(run('push', {}), EVERYTHING);
});

test('Dart change runs everything', () => {
  const files = ['packages/flutter/lib/src/sentry_flutter.dart'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), EVERYTHING);
});

test('CI change runs everything', () => {
  const files = ['.github/workflows/flutter.yml'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), EVERYTHING);
});

// getsentry/sentry-dart#4226
test('Android SDK bump runs only Android', () => {
  const files = ['packages/flutter/android/build.gradle'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), {
    ...NOTHING,
    android: 'true',
    flutter_matrix: flutterMatrix(['android', 'Android']),
  });
});

// getsentry/sentry-dart#4227
test('Cocoa SDK bump runs only iOS and macOS', () => {
  const files = [
    'packages/flutter/darwin/sentry_flutter/Package.swift',
    'packages/flutter/example/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    'packages/flutter/example/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    'packages/flutter/example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    'packages/flutter/example/macos/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
  ];
  assert.deepEqual(run('pull_request', filterOutputs(files)), {
    ...NOTHING,
    cocoa: 'true',
    flutter_matrix: flutterMatrix(['ios', 'iOS'], ['macos', 'macOS']),
  });
});

// getsentry/sentry-dart#4216
test('fastlane bump runs nothing', () => {
  const files = ['packages/flutter/example/ios/Gemfile.lock'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), NOTHING);
});

test('Cocoa and desktop changes run both platforms', () => {
  const files = ['packages/flutter/darwin/sentry_flutter/Package.swift', 'packages/flutter/linux/CMakeLists.txt'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), {
    ...NOTHING,
    cocoa: 'true',
    desktop: 'true',
    flutter_matrix: flutterMatrix(['ios', 'iOS'], ['macos', 'macOS'], ['linux', 'Linux'], ['windows', 'Windows']),
  });
});

test('native change with a Dart file runs everything', () => {
  const files = ['packages/flutter/android/build.gradle', 'packages/flutter/lib/src/sentry_flutter.dart'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), EVERYTHING);
});

test('native change with an unmatched script runs everything', () => {
  const files = ['packages/flutter/android/build.gradle', 'packages/flutter/scripts/update-android.sh'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), EVERYTHING);
});

test('package README runs only package analysis', () => {
  const files = ['packages/dio/README.md'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), { ...NOTHING, pana: 'true' });
});

test('package CHANGELOG runs only package analysis', () => {
  const files = ['packages/flutter/CHANGELOG.md'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), { ...NOTHING, pana: 'true' });
});

test('other docs run nothing', () => {
  const files = ['README.md', 'packages/flutter/example/README.md', 'packages/dart/class-diagram.svg'];
  assert.deepEqual(run('pull_request', filterOutputs(files)), NOTHING);
});

test('missing filter output fails instead of skipping jobs', () => {
  const outputs = filterOutputs(['packages/flutter/android/build.gradle']);
  delete outputs.ci_changed_files;
  assert.throws(() => run('pull_request', outputs), /ci_changed_files/);
});
