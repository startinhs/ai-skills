---
name: avntt-issue-workflow
description: "Workflow for processing AVNTT project issues from Excel/CSV worklogs into isolated issue branches with mandatory requirement analysis, git safety, TDD/static verification, trace comments, commit/push rules, and local worklog updates. Use when fixing bugs or handling UAT issues in the HQSOFT Xspire AVNTT repo, especially requests that mention Excel issue files, .codex-worklog, issue branches, release/1.0.0-avntt-rc1, or function-specific CSV filters."
---

# AVNTT Issue Workflow

## Overview

Use this skill to process one AVNTT issue at a time from a user-provided Excel/CSV source and the repo worklog. The workflow is deliberately conservative: read context first, use one branch per issue, avoid `develop`, verify before claiming done, push only the issue branch, and leave user/unrelated changes untouched.

## Required Companion Skill

Before any bug fix or behavior change, use `superpowers:brainstorming`.

Why it fits this workflow:

- Excel issues often omit exact fields, views, buttons, screenshots, or expected behavior.
- Many screens have duplicated views; fixing only one can be wrong.
- Business behavior must not be guessed from weak evidence.
- The agent must restate the issue, list ambiguous interpretations, propose options, and ask when requirements are unclear.

If `superpowers:brainstorming` is not available, stop before editing behavior and ask the user whether to install/setup it or use the fallback checklist for this session. The fallback checklist must include: read CSV/worklog/issue notes, restate the issue, identify screen/view/component, identify current and expected behavior, list alternatives if ambiguous, ask for confirmation when evidence is missing, and only implement after scope is clear.

## Reference Map

Read these references as needed:

- `references/issue-source.md`: Excel/CSV inputs, required columns, encoding, mismatch cases.
- `references/issue-workflow.md`: end-to-end issue flow and stop conditions.
- `references/git-branching.md`: branch/worktree/base/push rules.
- `references/verification.md`: RED/GREEN, static checks, build, trace comments.
- `references/worklog.md`: `.codex-worklog` update rules and final reporting.
- `assets/issue-template.csv`: header-only issue CSV template.

## Non-Negotiable Rules

- Work on exactly one `Issue No` per branch unless the user explicitly requests otherwise.
- Default base branch is `release/1.0.0-avntt-rc1`.
- Branch format is `fixbug-issue-{IssueNo}/{Owner}`.
- Infer `{Owner}` from the user's instruction, `.codex-worklog`, current issue branch, or existing remote/local branch. If still unknown, ask once before creating or switching branches.
- Never pull, merge, cherry-pick, push, or base new work on `develop`.
- Do not stage or commit `.codex-worklog/` or `Excel/` unless the user explicitly asks.
- Stage intended files explicitly. Never run `git add -A`.
- Preserve unrelated dirty/untracked files. Do not revert user changes.
- If a branch is held by another worktree, report the path and handle it safely.
- If requirements are unclear, ask before changing behavior.
- If an issue may affect duplicate views/files, identify them and ask before applying synchronized edits.

## Default Execution Flow

1. Read `.codex-worklog/state.md`, function progress, and the issue note if present.
2. Read the row for the target issue from the user-provided CSV/XLSX source.
3. Check `git status`, current branch, staged files, and worktrees.
4. Resolve `{Owner}`, sync `release/1.0.0-avntt-rc1`, then create/switch the issue branch.
5. Use `superpowers:brainstorming` to analyze the requirement before editing.
6. Establish the issue, branch, screen/view/component, current behavior, expected behavior, and file scope.
7. Run a RED check or a documented baseline static/regression check before the fix.
8. Implement the smallest scoped change.
9. Add mandatory trace comments for bugfixes in comment-capable source files.
10. Run GREEN checks and the required build unless the user explicitly overrides build.
11. Inspect diff for scope, stage files explicitly, commit using `.copilot/prompt/commit-prompt.md`.
12. If trace comments require the fix commit hash, add/update those comments after the fix commit, rerun verification, and commit the trace update.
13. Push only the issue branch to origin.
14. Update local worklog/progress/issue note, but do not commit those files unless requested.
15. Final response must state issue, branch, commits, push status, verification, and untouched dirty files.

## Trace Comment Format

For every bugfix in a comment-capable source file, add a short trace comment near the corrected logic:

```csharp
// Issue 1371 | fixbug-issue-1371/{Owner} | c3ae31bc4
// Keep detail audit records under the promotion header history.
```

Use the real issue number, branch owner, and fix commit hash in source comments. Because a commit hash cannot be embedded inside the same commit that creates it, use a second trace/comment commit when the user requires the hash in source.

If the changed file format does not support comments, do not break syntax. Record the trace in tests, worklog, or the nearest comment-capable source file that owns the behavior.

## Build Command

Default required build:

```powershell
dotnet build HQSOFT.Xspire.Application.sln -c Debug -p:WarningLevel=0 -p:NoWarn=NU1701%3BNU1608%3BNU1901%3BNU1902%3BNU1903%3BNU1904 -p:RunAnalyzers=false -m:4 -nodeReuse:false -tl
```
