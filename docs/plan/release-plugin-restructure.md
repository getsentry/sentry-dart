# Plan: Restructure Release Skill into Plugin

## Goal

Convert the current single-file release skill into a plugin with background execution support, allowing users to continue coding while the release workflow runs.

## Current State

```
.claude/skills/release/
└── SKILL.md                    # 320 lines, runs synchronously
```

**Problems:**
- Step 5 does `git switch release/<version>` which disrupts current work
- User cannot continue coding while workflow runs
- Long polling loops block the conversation

## Target State

```
.claude/plugins/release/
├── .claude-plugin/
│   └── plugin.json             # Plugin metadata
├── commands/
│   └── release.md              # Orchestrator command
└── agents/
    └── release-executor.md     # Background worker agent
```

**Benefits:**
- User can continue coding immediately after triggering
- Git operations happen in isolated worktree
- Background agent handles long-running tasks

---

## Component Specifications

### 1. plugin.json

```json
{
  "name": "release",
  "description": "Trigger and validate Sentry Dart/Flutter SDK releases with background execution",
  "author": {
    "name": "Sentry"
  }
}
```

### 2. commands/release.md (Orchestrator)

**Frontmatter:**
```yaml
---
description: Trigger a release with background validation
argument-hint: <version> <source_branch> <merge_target>
---
```

**Responsibilities (synchronous with user):**

| Step | Action | Blocks User? |
|------|--------|--------------|
| 1 | Parse and validate arguments | No |
| 2 | Analyze CHANGELOG for semantic version validation | No |
| 2b | Prerelease promotion validation (if applicable) | No |
| 3 | Get user confirmations (if warnings) | Yes (intentional) |
| 4 | Create worktree at `/tmp/release-<version>` | No |
| 5 | Spawn release-executor agent in background | No |
| 6 | Return immediately with status message | No |

**What moves to agent:**
- Triggering GitHub workflow
- Polling workflow status
- Fetching release branch
- Running validation checks
- Posting to publish issue
- Cleanup worktree

### 3. agents/release-executor.md (Background Worker)

**Frontmatter:**
```yaml
---
name: release-executor
description: Executes release workflow in background, monitors progress, validates, and reports results
tools: Bash, Read, Grep, Glob, WebFetch
model: sonnet
---
```

**Receives context from command:**
- `version`: The release version
- `source_branch`: Branch to release from
- `merge_target`: Branch to merge into
- `worktree_path`: Path to the created worktree

**Responsibilities (runs in background):**

| Step | Action |
|------|--------|
| 1 | Trigger release workflow via `gh workflow run` |
| 2 | Poll workflow status every 30 seconds |
| 3 | On completion, fetch release branch to worktree |
| 4 | Run validation checks (versions, CHANGELOG, sdk-versions) |
| 5 | Find publish issue and post validation results |
| 6 | Generate final summary |
| 7 | Cleanup worktree |

---

## Detailed Step Migration

### From SKILL.md Step 1-2b → commands/release.md

Keep as-is in the command. These are quick validation steps that should complete before spawning background work.

### From SKILL.md Step 3 → Split

**Command handles:**
- Show user what will be triggered
- Confirm before proceeding

**Agent handles:**
- Actually trigger `gh workflow run`
- Wait for run ID
- Show workflow URL (via final summary)

### From SKILL.md Step 4 → agents/release-executor.md

Move entirely to agent:
- Poll workflow status every 30 seconds
- Handle completion/failure

### From SKILL.md Step 5 → agents/release-executor.md

Replace branch switch with worktree operations:

```bash
# Command creates worktree (before spawning agent):
git worktree add /tmp/release-<version> <source_branch>

# Agent fetches and updates worktree:
cd /tmp/release-<version>
git fetch origin release/<version>
git checkout release/<version>
```

### From SKILL.md Step 6-7 → agents/release-executor.md

Move entirely to agent. Run all checks within worktree path.

### From SKILL.md Step 8 → agents/release-executor.md

Agent outputs final summary. User can check via `/tasks` or output file.

---

## Worktree Strategy

### Creation (by command)

```bash
git worktree add /tmp/release-<version> <source_branch>
```

- Creates isolated working directory
- Does not affect user's current branch
- Uses source_branch as starting point

### Usage (by agent)

```bash
cd /tmp/release-<version>
git fetch origin release/<version>
git checkout release/<version>
# Run all validation commands here
```

### Cleanup (by agent)

```bash
git worktree remove /tmp/release-<version>
```

- Agent cleans up when done (success or failure)
- Prevents worktree accumulation

---

## User Experience

### Before (Current)

```
User: /release 9.12.0 main main
Claude: [validates, confirms]
Claude: Triggering workflow...
Claude: Monitoring... (blocks for 5-10 minutes)
Claude: Switching branches... (disrupts work)
Claude: Running checks...
Claude: Done!
```

### After (New)

```
User: /release 9.12.0 main main
Claude: [validates, confirms]
Claude: Creating worktree at /tmp/release-9.12.0...
Claude: Starting release-executor agent in background...

Release workflow initiated!
- Version: 9.12.0
- Worktree: /tmp/release-9.12.0
- Monitor progress: /tasks

You can continue working. Results will be posted to the publish issue.

User: (continues coding normally)

# Later, agent completes and posts results to GitHub issue
```

---

## Implementation Order

1. **Create plugin structure**
   - Create directories
   - Create plugin.json

2. **Create commands/release.md**
   - Copy Steps 1-2b from SKILL.md
   - Add worktree creation logic
   - Add agent spawning logic
   - Add immediate return message

3. **Create agents/release-executor.md**
   - Copy Steps 3-8 from SKILL.md
   - Modify to work within worktree
   - Add cleanup logic
   - Ensure all paths use worktree

4. **Remove old skill**
   - Delete .claude/skills/release/SKILL.md
   - Or keep as backup during testing

5. **Test**
   - Test argument validation
   - Test CHANGELOG analysis
   - Test worktree creation
   - Test background execution
   - Test cleanup

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Worktree creation fails | Command checks and reports error before spawning agent |
| Agent fails mid-execution | Agent has cleanup in finally-block equivalent |
| User runs multiple releases | Use version in worktree path to avoid conflicts |
| Network issues during polling | Agent retries with backoff, eventually times out |

---

## Files to Create

1. `.claude/plugins/release/.claude-plugin/plugin.json`
2. `.claude/plugins/release/commands/release.md`
3. `.claude/plugins/release/agents/release-executor.md`

## Files to Delete

1. `.claude/skills/release/SKILL.md` (after testing)

---

## Open Questions

1. Should we keep the old skill as a fallback during transition?
2. What's the maximum timeout for workflow polling? (Current: unlimited)
3. Should the agent notify the user in-conversation when done, or only via GitHub?
