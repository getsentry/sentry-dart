# Known False Positives

Maintainers declined these findings on 2026 PRs. **Don't report them again** unless the diff changes the fact a finding depends on. Each entry gives the wrong claim, why it's wrong, and the PR where it came up.

When a maintainer declines a review finding as a false positive, add it here. Keep each entry to one line, and state the general fact instead of the single case.

## Dart, Flutter, and native interop

- **`{this._x}` "renames the public parameter to `_x`."** Wrong. Dart 3.12 private named parameters still expose the public named parameter `x`. (#4072, twice)
- **`Directory(jFile.toString())` "uses the JNI wrapper's string."** Wrong. `package:jni`'s `JObject.toString()` calls the Java object's `toString()`, so a `java.io.File` gives its path. (#4037)
- **"`X` is not a Flutter / Dart API."** Check the SDK floor in the package's `pubspec.yaml` before you claim this. `PageTransitionsBuilder.transitionDuration` has existed since Flutter 3.29. (#4056)

## Sentry JS SDK (Flutter web)

- **"Buffer-mode replay IDs are dropped by `getReplayId(onlyIfSampled: true)`."** Wrong. The JS SDK returns no ID only when `session.sampled === false`. In buffer mode `sampled` is `'buffer'`, so the ID is returned. (#4059, three times)
- **"Labels or breadcrumbs leak into replay through `Sentry.addBreadcrumb`."** JS Replay's `normalizeBreadcrumb` drops the `ui.*`, `fetch`, `xhr`, and `sentry.*` categories. Other categories, like `http` and `navigation`, already reach the replay timeline. (#4059, twice)
- **"Web manual replay start can't bypass sampling."** This is intentional. The Replay bundle loads only when a replay sample rate is above 0. (#4059)

## Conventions and tooling

- **OTel RPC attribute names.** The current semconv uses general `rpc.*` keys: `rpc.system.name`, `rpc.response.status_code`, and `rpc.request.metadata.<key>`. Don't push the older `rpc.system` or `rpc.grpc.*` names. (#3721, three times)
- **A DSN in an example app or test is "a leaked secret."** Wrong. A DSN is a public client key that is meant to ship in apps. (#3721)
- **CMake `file(DOWNLOAD … STATUS)` "ignores HTTP errors."** Wrong. It returns a non-zero status for 4xx/5xx responses. (#4110)
- **GitHub Actions workflow-command injection from test output in the same job.** Code in that job already runs arbitrary commands, so no trust boundary is crossed. (#3750)
- **"Action release `vX.Y.Z` / SHA does not exist."** Don't assert this from memory. New releases come out after your training data. (#3917, twice)

## Scope

- **A breaking change with no deprecation path, when the change is intentional.** Don't flag it when the PR title has `!` (e.g. `feat(dart)!:`), the body has `BREAKING CHANGE`, or the base is a major-version branch. (#3964, twice)
- **"No test coverage"** when `example/integration_test/` covers the path. Search there before you report missing tests. (#3708)
- **Issues that already exist on the base branch.** This includes code that a merge PR or a dependency bump only carries. Report only what the diff introduces. (#4072, twice; #3941)
- **A prerequisite that the PR body already lists**, e.g. "requires a Cocoa release with API X". (#4100)
