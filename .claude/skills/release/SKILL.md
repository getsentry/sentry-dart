---
name: release
description: Trigger and validate a Sentry Dart/Flutter SDK release with automated release validation
arguments:
  - name: version
    description: Version to release (semver format, e.g., 9.12.0 or 9.12.0-beta.1)
    required: true
  - name: source_branch
    description: Branch to release from (e.g., main, release/9.12.x)
    required: true
  - name: merge_target
    description: Branch to merge the release PR into (e.g., main)
    required: true
---

# Release Skill for Sentry Dart/Flutter SDK

This skill automates the release workflow with validation, monitoring, and release validation.

## Usage

```
/release <version> <source_branch> <merge_target>
```

Example: `/release 9.12.0 main main`

## Workflow Steps

Follow these steps IN ORDER. Do not skip steps.

### Step 1: Parse and Validate Arguments

1. Extract `version`, `source_branch`, and `merge_target` from the arguments
2. If any argument is missing, ask the user to provide all three:
   - "Please provide version, source branch, and merge target: `/release <version> <source_branch> <merge_target>`"
   - Example: `/release 9.12.0 main main`

3. Validate the version format matches semver:
   - Valid: `X.Y.Z`, `X.Y.Z-beta.N`, `X.Y.Z-rc.N`, `X.Y.Z-alpha.N`
   - X, Y, Z, N must be non-negative integers
   - If invalid, show error and stop

4. Determine version type:
   - **PATCH**: Z > 0 and no prerelease suffix (e.g., `9.12.1`)
   - **MINOR**: Z = 0 and Y > 0 and no prerelease suffix (e.g., `9.12.0`)
   - **MAJOR**: Y = 0 and Z = 0 (e.g., `10.0.0`)
   - **PRERELEASE**: Has `-beta`, `-rc`, or `-alpha` suffix
   - **PROMOTION**: Releasing a stable version (e.g., `9.12.0`) when prerelease versions exist (e.g., `9.12.0-beta.1`)

### Step 2: Analyze CHANGELOG for Semantic Version Validation

1. Read the CHANGELOG.md file
2. Find the "Unreleased" section or the topmost version section
3. Identify which subsections exist:
   - `### Features` - New functionality
   - `### Enhancements` - Improvements to existing features
   - `### Fixes` - Bug fixes
   - `### Dependencies` - Dependency updates

4. Apply semantic versioning rules:

   **For PATCH releases:**
   - ALLOWED: Only `Fixes` section
   - WARNING if `Features`, `Enhancements`, or `Dependencies` exist:
     > "Warning: CHANGELOG contains Features/Enhancements/Dependencies but you're releasing a PATCH version.
     > This should likely be a MINOR release. Continue anyway? (yes/no)"
   - Wait for user confirmation before proceeding

   **For MINOR releases:**
   - EXPECTED: Should have `Features`, `Enhancements`, OR `Dependencies` section
   - WARNING if only `Fixes`:
     > "Warning: CHANGELOG only contains Fixes. This could be a PATCH release instead.
     > Continue with MINOR release anyway? (yes/no)"
   - Wait for user confirmation before proceeding

   **For MAJOR releases:**
   - ALWAYS ask for confirmation:
     > "You are releasing a MAJOR version. This indicates breaking changes.
     > Please confirm this is intentional. (yes/no)"
   - Wait for user confirmation before proceeding

### Step 2b: Prerelease Promotion Validation

**This step only applies when promoting a prerelease to stable** (e.g., `9.12.0-beta.1` → `9.12.0`).

1. Check if this is a promotion by looking for existing prerelease versions in the CHANGELOG:
   - Search for entries like `## X.Y.Z-beta.N`, `## X.Y.Z-rc.N`, `## X.Y.Z-alpha.N` where `X.Y.Z` matches the target version

2. If prerelease versions exist, collect all their changelog entries:
   - List all `### Features`, `### Enhancements`, `### Fixes`, `### Dependencies` from each prerelease

3. Compare with the current "Unreleased" section:
   - All entries from prerelease versions should be consolidated into the Unreleased section
   - This ensures the stable release includes the full history of changes

4. If entries are MISSING from the Unreleased section:
   ```
   Warning: Promoting 9.12.0-beta.1 to 9.12.0, but the Unreleased section
   may be missing entries from the prerelease versions.

   Found in 9.12.0-beta.1 but not in Unreleased:
   - [list missing entries]

   Is this intentional? Some entries may have been removed or consolidated.
   Continue anyway? (yes/no)
   ```
   - Wait for user confirmation before proceeding

5. If all entries are present or user confirms, continue to Step 3

### Step 3: Trigger the Release Workflow

1. Show the user what you're about to do:
   ```
   Triggering release workflow:
   - Version: <version>
   - Source Branch: <source_branch>
   - Merge Target: <merge_target>
   - Repository: getsentry/sentry-dart
   ```

2. Trigger the workflow:
   ```bash
   gh workflow run release.yml \
     --repo getsentry/sentry-dart \
     --ref <source_branch> \
     -f version=<version> \
     -f merge_target=<merge_target>
   ```

3. If the trigger fails, show the error and stop

4. Wait up to 20 seconds for the workflow to register, then get the run ID:
   ```bash
   gh run list --workflow=release.yml --repo getsentry/sentry-dart --limit=1 --json databaseId,status,createdAt
   ```

5. Show the user the workflow URL:
   ```
   Release workflow triggered!
   Run ID: <run_id>
   URL: https://github.com/getsentry/sentry-dart/actions/runs/<run_id>
   ```

### Step 4: Wait for Workflow Completion

1. Tell the user you're monitoring the workflow:
   ```
   Monitoring workflow progress... (this may take several minutes)
   ```

2. Poll the workflow status every 30 seconds:
   ```bash
   gh run view <run_id> --repo getsentry/sentry-dart --json status,conclusion
   ```

3. Show status updates to the user:
   - `queued` → "Workflow queued..."
   - `in_progress` → "Workflow running..."
   - `completed` → Check conclusion

4. When completed:
   - If `conclusion` is `success`: Continue to Step 5
   - If `conclusion` is `failure`:
     ```
     Release workflow FAILED!
     Check the logs: https://github.com/getsentry/sentry-dart/actions/runs/<run_id>
     ```
     Stop here.

### Step 5: Switch to the Release Branch

1. Fetch the release branch:
   ```bash
   git fetch origin release/<version>
   ```

2. Checkout the branch:
   ```bash
   git switch release/<version>
   ```

3. If switch fails, show error and stop

### Step 6: Run Release Validation

Run each check and record results. Use this tracking format:

```
## Release Validation Results

| Check | Status | Details |
|-------|--------|---------|
```

#### Check 1: Version in pubspec.yaml files

Check all 12 packages have the correct version:
```bash
grep -r "^version: " packages/*/pubspec.yaml
```

- PASS: All show `version: <version>`
- FAIL: Any mismatch - list which files are wrong

#### Check 2: Version in version.dart files

Check all packages have correct sdkVersion:
```bash
grep -r "sdkVersion = " packages/*/lib/src/version.dart
```

- PASS: All show `'<version>'`
- FAIL: Any mismatch - list which files are wrong

#### Check 3: CHANGELOG entry exists

Check CHANGELOG.md has the version header:
```bash
grep "^## <version>" CHANGELOG.md
```

- PASS: Entry `## <version>` exists
- FAIL: Entry missing

#### Check 4: sdk-versions.md updated

Check the SDK versions table has the new version:
```bash
head -20 docs/sdk-versions.md
```

- PASS: First data row contains `<version>`
- FAIL: Version not in table or not in first row

### Step 7: Find and Comment on Publish Issue

1. Search for the release issue in getsentry/publish:
   ```bash
   gh issue list --repo getsentry/publish --search "sentry-dart <version>" --json number,title,url --limit 5
   ```

2. If no issue found:
   ```
   Note: No matching issue found in getsentry/publish for sentry-dart <version>
   You may need to manually post the results.
   ```
   Show the release validation summary and stop.

3. If issue found, compose the comment:

```markdown
## Release Validation: sentry-dart <version>

### What's in this release

- Summarize the CHANGELOG in plain language
- Focus on user value, not technical implementation details
- Write for someone unfamiliar with the codebase

### Checks

| Check | Status | Details |
|-------|--------|---------|
< for each check from Step 6, add a row with check name, ✅ PASS or ❌ FAIL, and details >

### Verdict: **<APPROVED/NOT APPROVED>**

< if NOT APPROVED, list the reasons >

---
Automated check by Claude Code
```

4. Post the comment:
   ```bash
   gh issue comment <issue_number> --repo getsentry/publish --body "<comment>"
   ```

5. Show the user the issue URL:
   ```
   Posted release validation results to: <issue_url>
   ```

### Step 8: Final Summary

Show the user a final summary:

```
## Release <version> Summary

Workflow: SUCCESS
Source Branch: <source_branch>
Release Branch: release/<version>
Merge Target: <merge_target>
PR: <pr_url>
Publish Issue: <issue_url>

Release Validation Verdict: <APPROVED/NOT APPROVED>

<If approved>
The release is ready for final review and merge.

<If not approved>
Issues found that need attention:
- <list issues>
```

## Error Handling

- If any GitHub CLI command fails, show the error output and suggest next steps
- If the workflow fails, provide a link to the logs
- If validation checks fail, continue with remaining checks and report all failures
- Always provide actionable next steps when something goes wrong

## Notes

- This skill does NOT support the `--force` flag for release blockers
- Release blockers must be resolved before running this skill
- For hotfix releases, use a different source branch (e.g., `release/9.12.x`) and appropriate merge target
- When promoting prereleases to stable, ensure all prerelease changelog entries are consolidated
