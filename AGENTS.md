# Sentry Dart/Flutter SDK - Agent Guide

## Overview

Sentry is a developer-first error tracking and performance monitoring platform.
This repository contains the Sentry Dart/Flutter SDK and integrations.

## Project Structure

- `packages/dart/` - Core Sentry Dart SDK
- `packages/flutter/` - Sentry Flutter SDK (includes native integrations)
- `packages/dio/` - Dio HTTP client integration
- `packages/drift/` - Drift database integration
- `packages/file/` - File I/O integration
- `packages/hive/` - Hive database integration
- `packages/isar/` - Isar database integration
- `packages/sqflite/` - SQLite integration
- `packages/logging/` - Dart logging package integration
- `packages/supabase/` - Supabase integration
- `packages/firebase_remote_config/` - Firebase Remote Config integration
- `packages/link/` - Deep linking integration
- `docs/` - Documentation
- `e2e_test/` - End-to-end test suite
- `min_version_test/` - Minimum SDK version compatibility tests
- `metrics/` - Size and performance metrics tooling
- `scripts/` - Build, release, and utility scripts
- `melos.yaml` - Melos monorepo configuration

## Environment

- Flutter: `3.24.0` | Dart: `3.5.0`
- Use `fvm dart` / `fvm flutter` if available (check with `which fvm`), else `dart` / `flutter`

### Package Types

Check `pubspec.yaml` to determine package type:

- **Dart-only**: No `flutter:` in `environment:` section (e.g., `sentry`, `sentry_dio`)
- **Flutter**: Has `flutter:` constraint (e.g., `sentry_flutter`, `sentry_sqflite`)

### Commands

Run from within the package directory (e.g., `packages/dart/`):

- Test: `dart test` (Dart) or `flutter test` (Flutter)
- Analyze: `dart analyze` (Dart) or `flutter analyze` (Flutter)
- Format: `dart format <path>`
- Fix: `dart fix --apply`
- Web Test: `flutter test -d chrome`

## Agent Documentation

Read these files **only when relevant** to your current task:

- `docs/agent_instructions/test-conventions.md` - Writing or modifying tests
- `docs/agent_instructions/code-guidelines.md` - Implementing new features, refactoring, or reviewing code

## Key Principles

- **Development**: Always ask clarifying questions if needed and/or propose a plan before implementation
- **Test First**: Write failing tests before implementation; fix regressions with a reproducing test first
- **Git Usage**: **NEVER** commit or push code
