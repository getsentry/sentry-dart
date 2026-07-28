---
name: review
description: Three-axis review of the branch diff — Standards (this repo's documented standards + public API surface), Spec (the originating Linear issue / PR), and Correctness (runtime bugs + the SDK threat model — PII, native leaks, buffers, serialization, concurrency). Runs the axes as parallel sub-agents and reports them side by side. Use when reviewing a branch, a PR, or work-in-progress changes before opening or merging, or "review since X".
---

Review the diff between `HEAD` and a base, on three axes:

- **Standards** — does the diff conform to this repo's documented standards?
- **Spec** — does it faithfully implement the originating issue / PR?
- **Correctness** — will it actually work, and is it safe?

Run the axes as **parallel sub-agents** so none pollutes another's context, then aggregate. Report them side by side, and **never rerank across axes** — keeping them separate is the whole point (see *Why separate axes*).

This is the every-PR pass. It complements `security-review` (deeper security audit) and `span-convention-review` (tracing-span conventions) — invoke those for depth. It is *not* a debugger: when a bug is already known and reproducing, use `diagnosing-bugs` instead.

## 1. Pin the base

Use whatever base the user named — a commit, branch, tag, or `HEAD~N`. If they named none, default to the merge-base with the default branch (`git merge-base HEAD origin/main`). Capture once:

- `git diff <base>...HEAD` (three-dot, so it compares against the merge-base)
- `git log <base>..HEAD --oneline`

Confirm the ref resolves (`git rev-parse <base>`) and the diff is non-empty. A bad ref or empty diff fails **here** — not inside parallel sub-agents.

## 2. Identify the spec source

Look for the originating spec, in order:

1. Linear issue references in commit messages or the PR (fetch the issue via the Linear tools).
2. The PR description (motivation / what it does).
3. A path the user passed.

If none is found, ask. If there genuinely is no spec, the Spec sub-agent skips and reports "no spec available".

## 3. Spawn the sub-agents in parallel

Send one message with three `Agent` tool calls (general-purpose subagent for each). Give each the diff command and the commit list, plus its brief:

**Standards sub-agent:**

> Read `.agents/skills/code-guidelines/SKILL.md` and `.agents/skills/test-guidelines/SKILL.md`, then review the diff against them.
> **Top priority — public API surface:** for any change to a barrel file (`lib/sentry.dart`, `lib/sentry_flutter.dart`, or an integration package's barrel), classify each exported symbol as added / removed / signature-changed / behavior-changed. Flag every removal or incompatible change as a **breaking change** (semver-major) and check it carries a deprecation path (per code-guidelines).
> Then report, per file/hunk, every place the diff violates a documented standard — cite the rule. For areas the docs don't cover, apply the smell baseline in `.agents/skills/review/references/smell-baseline.md` as judgement calls. Distinguish hard violations from judgement calls; a documented standard overrides the baseline. Skip anything `dart analyze` / `dart format` / lints enforce. Under 400 words.

**Spec sub-agent** (skip and note if no spec):

> Report: (a) requirements the spec asked for that are missing or partial; (b) behavior in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but wrong. Quote the spec line for each finding. Under 400 words.

**Correctness sub-agent:**

> Find bugs and unsafe code the diff introduces — not style, which Standards owns. Check, per file/hunk:
> - **Runtime bugs** — unawaited / fire-and-forget futures, uncancelled stream subscriptions, `late` used before init, null/empty edge cases, swallowed errors, missing cleanup in `close()` / `dispose()`, races / TOCTOU.
> - **SDK threat model** — PII collected without gating on `options.sendDefaultPii`; sensitive data leaking into breadcrumbs, logs, or event payloads; native memory not released (JNI local refs, `malloc`) or a native exception that could crash the host app; unbounded buffers / queues / caches (memory growth); serialization correctness (`toJson`/`fromJson` round-trip, null handling); isolate / thread safety; rate-limiter or retry correctness.
> For each finding give file:line, a one-line severity (critical/high/medium/low), why it's real (not already handled, no covering test), and a concrete fix. Skip anything the analyzer or existing tests already catch. Under 400 words.

## 4. Aggregate

Present the reports under `## Standards`, `## Spec`, and `## Correctness` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings across axes.

End with a one-line summary per axis: total findings, and the worst issue *within that axis*. Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

## Why separate axes

A change can pass on one axis and fail on another, and a merged list lets one mask the others:

- Follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Does what the issue asked but breaks conventions → **Spec pass, Standards fail.**
- Clean and on-spec but leaks a native ref or drops a `sendDefaultPii` check → **Standards & Spec pass, Correctness fail.**

Reporting them separately stops any one axis from hiding another.
