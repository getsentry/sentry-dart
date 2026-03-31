# Sentry Dart/Flutter SDK

Melos monorepo. Each package lives in `packages/<name>/` with its own `pubspec.yaml`.

## Packages

| Directory | Description                                      |
|-----------|--------------------------------------------------|
| `packages/dart/` | Core Sentry Dart SDK                             |
| `packages/flutter/` | Sentry Flutter SDK (includes native integrations) |
| `packages/dio/` | Dio HTTP client integration                      |
| `packages/drift/` | Drift database integration                       |
| `packages/file/` | File I/O integration                             |
| `packages/hive/` | Hive database integration                        |
| `packages/isar/` | Isar database integration                        |
| `packages/sqflite/` | SQLite integration                               |
| `packages/logging/` | Dart logging integration                         |
| `packages/supabase/` | Supabase integration                             |
| `packages/firebase_remote_config/` | Firebase Remote Config integration               |
| `packages/link/` | GraphQL integration                              |

## Environment

- Flutter `3.24.0` | Dart `3.5.0`
- Use `fvm dart` / `fvm flutter` if available (check with `which fvm`), else `dart` / `flutter`

## Package Types

Check `pubspec.yaml` `environment:` section:

- **Dart-only** (no `flutter:` key): `sentry`, `sentry_dio`, `sentry_file`, `sentry_logging`
- **Flutter** (has `flutter:` key): `sentry_flutter`, `sentry_sqflite`, `sentry_drift`, etc.

## File-Scoped Commands

Run from within the package directory (e.g., `cd packages/dart/`):

| Task | Dart-only | Flutter |
|------|-----------|---------|
| Test | `dart test path/to/test.dart` | `flutter test path/to/test.dart` |
| Analyze | `dart analyze path/to/file.dart` | `flutter analyze path/to/file.dart` |
| Format | `dart format path/to/file.dart` | `dart format path/to/file.dart` |
| Fix | `dart fix --apply` | `dart fix --apply` |
| Web test | — | `flutter test -d chrome path/to/test.dart` |

## Conventions

- Ask clarifying questions and/or propose a plan before implementation
- Write failing tests before implementation; fix regressions with a reproducing test first
- **NEVER** commit or push code unless explicitly asked
- See `CONTRIBUTING.md` for setup and contribution workflow

## Command Execution

- **Verify working directory** — use `pwd` to confirm you're in the correct path before running commands. The shell persists working directory across tool calls
- **Avoid redundant `cd`** — do not prefix every command with `cd <path> &&`. Change directory once if needed, then verify with `pwd`
- **Wildcard permissions** — many commands are pre-approved with wildcards (e.g., `git add:*`). Flags like `-C` change the command prefix (`git -C path add` ≠ `git add`), triggering a confirmation prompt. Avoid `-C` when you can change directory instead
- **Prefer small, focused commands** over one massive pipeline. Break complex operations into multiple steps
- **JSON processing** — always use `jq`; do not shell out to `node` or `python` for JSON parsing
- **GitHub** — prefer `gh` CLI over web scraping when interacting with GitHub.com

## Commits

- **Conventional Commits 1.0.0** — subject max 50 chars, body max 72 chars/line
- **AI attribution** — AI-generated commits must include a `Co-Authored-By` footer (e.g., `Co-Authored-By: Claude <noreply@anthropic.com>`)
- **File renames** — always use `git mv`, never `mv` + `git add`

| Type    | Changelog? | Purpose                               |
| ------- | ---------- | ------------------------------------- |
| `feat`  | yes        | New feature (MINOR)                   |
| `fix`   | yes        | Bug fix (PATCH)                       |
| `impr`  | yes        | Improvement to existing functionality |
| `ref`   | no         | Refactoring (no behavior change)      |
| `test`  | no         | Test additions/corrections            |
| `docs`  | no         | Documentation only                    |
| `build` | no         | Build system/dependencies             |
| `ci`    | no         | CI configuration                      |
| `chore` | no         | Maintenance                           |
| `perf`  | no         | Performance improvement               |
| `style` | no         | Formatting (no logic change)          |

Non-changelog types require `#skip-changelog` in PR description. Breaking changes: `feat!:` or `BREAKING CHANGE:` footer.

## Pull Requests

- **Title** — same format as commit subject (Conventional Commits): `type: description`
- **Branch naming** — `<type>/<short-description>` (e.g., `feat/session-replay-privacy`, `fix/memory-leak-scope`)
- **PR template** — `.github/pull_request_template.md` includes: description, motivation, how tested, checklist
- **Reviewers** — assigned via `CODEOWNERS` (`.github/CODEOWNERS`); one maintainer approval is sufficient
- **Changelog** — `feat`, `fix`, `impr` PRs need a changelog entry; all others need `#skip-changelog` in the description
- **Draft PRs** — use for work-in-progress; convert to ready when seeking review
- **CI automation** — Danger runs on PR open/sync/edit (shared Dangerfile from `getsentry/github-workflows`)

## Context-Aware Loading

Use the right AGENTS.md for the area you're working in:

- **Core SDK** (`packages/dart/`) → `packages/dart/AGENTS.md`
- **Flutter SDK** (`packages/flutter/`) → `packages/flutter/AGENTS.md`
- **General** → This file for monorepo-wide commands and conventions

## Skills

- **test-conventions** — Writing or modifying tests
- **code-guidelines** — Implementing features, refactoring, or reviewing code

## Maintaining Agent Docs

When you hit a wall that an instruction would have prevented, a documented command/path is wrong, or a convention has changed — propose an update to the relevant file:

- `AGENTS.md` — commands, environment, package structure, conventions
- `.agents/skills/test-conventions/SKILL.md` — Writing or modifying tests
- `.agents/skills/code-guidelines/SKILL.md` — Implementing features, refactoring, or reviewing code

Do NOT add task-specific fixes, things discoverable from code, or duplicates of what linters enforce. Always propose changes — do not silently edit these files.
