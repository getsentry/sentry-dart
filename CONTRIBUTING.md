<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Contributing

Thanks for your interest in contributing to `sentry-dart`! This guide explains how we work with external contributions and how to get your environment set up. If you have questions, reach out on [Discord](https://discord.com/invite/sentry).

## Submitting Changes

**TL;DR: Discuss your change in a GitHub issue before opening a pull request. We may close PRs that weren't discussed with a maintainer first.**

Every line we merge is code we maintain long-term for hundreds of thousands of apps, so we want to agree on the problem and the approach before anyone writes code. This saves time for you and for us.

### Before You Start

1. **Find or create an issue.** Search the [issue tracker](https://github.com/getsentry/sentry-dart/issues) first. If nothing fits, open a new issue describing the problem or feature.
2. **Discuss your approach with a maintainer.** Comment on the issue with what you plan to change and wait for a maintainer to respond before you start working.
3. **Check the assignee.** If the issue is already assigned to someone else, coordinate with them in the issue before starting work.

### Making Your Contribution

- Fork the repo and make your changes on a branch.
- Add tests. Non-trivial PRs won't be accepted without them.
- Don't bump version numbers. We do that when we release.
- Open a PR that links the issue (e.g. `Fixes #123`)
- Name your PR according to our [commit message format](https://develop.sentry.dev/commit-messages/#commit-message-format).
- Keep PRs focused: one change per PR, no unrelated refactors.

### AI Use

You are welcome to use whatever tools you prefer for making a contribution. However, any changes you propose have to be understood, reviewed and tested by you, a human, first, before you submit a pull request with them for the Sentry team to review. If we feel like that didn't happen, we will close the PR outright. For example, we won't review visibly AI-generated PRs from an agent instructed to look for and "fix" open issues in the repo. This aligns with our SDK principle: [every line has an owner](https://develop.sentry.dev/sdk/getting-started/principles/#every-line-has-an-owner).

## Prerequisites

### Required Tools

* **Dart SDK** `>=3.12.0` - Required for all packages
* **Flutter SDK** `>=3.44.0` - Required for `sentry-flutter` and Flutter integrations
* **[fvm](https://fvm.app/)** - For Flutter/Dart version management
* **[melos](https://melos.invertase.dev/)** - For managing the monorepo
* **[jq](https://jqlang.org/)** - For reading the shared toolchain configuration

## Environment Setup

### 1. Install fvm and melos

```bash
dart pub global activate fvm
dart pub global activate melos
```

### 2. Install the Flutter SDK via fvm

```bash
fvm install
```

This reads `.fvmrc` and installs the pinned Flutter version. It also creates a `.fvm/flutter_sdk`
symlink that melos uses to resolve `dart`/`flutter` commands (via `sdkPath` in `melos.yaml`).
Formatting, analysis, and binding generation use this development toolchain, including its
bundled Dart SDK for Dart-only packages. Compatibility tests separately cover the minimum
supported and stable/beta SDKs.

To upgrade the development toolchain, update `.fvmrc`, run `fvm install` and `melos bootstrap`,
then regenerate bindings and format the repository with that SDK. Include any resulting
formatting changes in the same PR.

### 3. Bootstrap the project

```bash
melos bootstrap
```

This resolves all package dependencies and configures git hooks for pre-commit checks.

### 4. Common commands

Run these from the repo root. Use `melos run --list` to see all available scripts and their
descriptions.

| Command | What it does |
|---------|--------------|
| `melos run analyze:dart` | Run `dart analyze` on Dart-only packages |
| `melos run analyze:flutter` | Run `flutter analyze` on Flutter packages |
| `melos run format` | Apply formatting to all packages |
| `melos run test:dart` | Run tests for Dart-only packages |
| `melos run test:flutter` | Run tests for Flutter packages |
| `melos run example:flutter -- <platform>` | Build & run the Flutter example (`ios`, `android`, `web`, `macos`, or `linux`; not supported on Windows, since melos runs scripts through `cmd.exe` there) |

## Project Structure

### Core SDKs

* **[packages/dart](https://github.com/getsentry/sentry-dart/tree/main/packages/dart)** - Core Dart
  SDK (`sentry` package)
* **[packages/flutter](https://github.com/getsentry/sentry-dart/tree/main/packages/flutter)** -
  Flutter SDK (`sentry_flutter` package)

### Integration Packages

Located under `packages/`, we maintain integrations for popular Dart/Flutter libraries:

* **sentry_dio** - HTTP client integration for [dio](https://pub.dev/packages/dio)
* **sentry_logging** - Integration for the [logging](https://pub.dev/packages/logging) package
* **sentry_sqflite** - Integration for [sqflite](https://pub.dev/packages/sqflite) database
* **sentry_drift** - Integration for [drift](https://pub.dev/packages/drift) database
* **sentry_hive** - Integration for [hive](https://pub.dev/packages/hive) database
* **sentry_isar** - Integration for [isar](https://pub.dev/packages/isar) database
* **sentry_file** - Integration for File I/O operations
* **sentry_link** - Integration for GraphQL via [gql_link](https://pub.dev/packages/gql_link)
* **sentry_firebase_remote_config** - Integration
  for [firebase_remote_config](https://pub.dev/packages/firebase_remote_config)

## Platform Support

The Flutter SDK supports the following platforms:

* iOS
* macOS
* Android
* Web
* Linux
* Windows

We test the example app on Windows, macOS, and Linux to ensure cross-platform compatibility. CI runs
against Flutter `stable` and `beta` channels.

### Building the macOS example

On macOS, Flutter derives the local SwiftPM package identity from the plugin's directory basename
(`flutter`) rather than its pub name (`sentry_flutter`), so `flutter build macos` from
`packages/flutter/example` fails with:

```
unable to override package 'sentry_flutter' because its identity 'flutter'
doesn't match override's identity (directory name) 'sentry_flutter'
```

Use the helper script (or its melos alias), which temporarily renames the package directory to
`sentry_flutter`, builds, then restores it:

```bash
melos run build:macos-example
# or, forwarding extra flags to `flutter build macos`:
./scripts/build-macos-example.sh --debug
```

This only affects the macOS example build; iOS is unaffected.

## Native SDK Dependencies

The Flutter SDK embeds platform-specific native SDKs:

* **Android**: [sentry-java](https://github.com/getsentry/sentry-java) (via
  Gradle) + [sentry-native](https://github.com/getsentry/sentry-native) for NDK
* **iOS/macOS**: [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) (via SwiftPM)
* **Linux/Windows**: [sentry-native](https://github.com/getsentry/sentry-native) (bundled in
  `packages/flutter/sentry-native/`)
* **Web**: [sentry-javascript](https://github.com/getsentry/sentry-javascript) (loaded via CDN)

## Pre-commit Hooks

After `melos bootstrap`, git is configured to use `.githooks/` for hooks. The pre-commit hook
automatically:

1. **Auto-formats** staged `.dart` files and re-stages them
2. **Runs `dart analyze`** on changed Dart-only packages
3. **Runs `flutter analyze`** on changed Flutter packages

Only packages with staged changes are analyzed — no need to wait for the full monorepo.

## Branch Naming

Use the format `git-username/type/short-description` for branch names.

* `git-username` should match your Git username or GitHub handle.
* `type` should be a conventional change type according to [conventional commits](https://www.conventionalcommits.org/) such as `feat`, `fix`, `docs`, `test`, or `chore`.
* `short-description` should be lowercase, hyphen-separated, and describe the change.

For example: `octocat/feat/add-http-timeout`.

## Changelog

Changelogs are generated automatically during the release process using
[craft](https://github.com/getsentry/craft). The policy is defined in
[`.github/release.yml`](.github/release.yml).

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) format (e.g.,
`feat(scope): Add feature`, `fix: Handle null`) since craft uses them to categorize entries and
determine the semver bump. No manual changelog entries are needed. A changelog preview is posted on
each PR so you can verify how the entry will look before merging.

If a PR should be excluded from the changelog, apply the `skip-changelog` label.

If a PR should notify a linked issue after release, use a GitHub closing keyword in the PR
description, such as `Fixes #123`, `Closes #123`, or `Resolves #123`. Release notification
automation only comments on issues GitHub recognizes as closed by the released PR; mentioning an
issue without a closing keyword is not enough.

### Custom Changelog Entries from PR Descriptions

By default, the changelog entry for a PR is generated from its title. However, PR authors can
override this by adding a "Changelog Entry" section to the PR description. This allows for more
detailed, user-facing changelog entries without cluttering the PR title.

Add a markdown heading (level 2 or 3) titled "Changelog Entry" to your PR description, followed by
the desired changelog text:

```markdown
### Description

Add `foo` function, and add unit tests to thoroughly check all edge cases.

### Motivation & Context

Closes #123

### Changelog Entry

Add a new function called `foo` which prints "Hello, world!"
```

The text under "Changelog Entry" will be used verbatim in the changelog instead of the PR title. If
no such section is present, the PR title is used as usual.

## Code Style

We follow [Effective Dart](https://dart.dev/effective-dart) conventions.
