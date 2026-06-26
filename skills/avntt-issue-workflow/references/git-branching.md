# Git And Branching

Use this reference before creating or switching branches.

## Baseline

Run these checks first:

```powershell
git status --short --branch
git diff --staged --name-only
git worktree list
```

Also check whether the repo is in merge/rebase/cherry-pick state.

## Base Branch

Default base branch:

```text
release/1.0.0-avntt-rc1
```

Before creating a new issue branch:

```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
```

If the current worktree has unrelated dirty files, use a separate worktree or ask before switching. Never discard those changes.

## Issue Branch

Issue branch format:

```text
fixbug-issue-{IssueNo}/{Owner}
```

Resolve `{Owner}` before creating or switching branches:

- Use the owner explicitly provided by the user.
- Otherwise infer it from `.codex-worklog`, the current branch, an existing local branch, or an existing remote branch for the same issue.
- If multiple owners exist for the same issue, list them and ask which one to use.
- If no owner can be inferred, ask: `Branch owner suffix dùng cho issue này là gì? Ví dụ: toantv, duhk, tinhlm.`
- After `{Owner}` is resolved, reuse it consistently in branch name, push command, trace comments, and worklog.

If the branch exists locally, switch to it after verifying it is not held by another worktree.

If the branch exists on origin but not locally:

```powershell
git fetch origin fixbug-issue-{IssueNo}/{Owner}
git checkout -b fixbug-issue-{IssueNo}/{Owner} origin/fixbug-issue-{IssueNo}/{Owner}
```

If the branch does not exist:

```powershell
git checkout -b fixbug-issue-{IssueNo}/{Owner}
```

## Forbidden

- Do not use `develop` as a base.
- Do not pull, merge, or cherry-pick from `develop`.
- Do not push or merge into `develop`.
- Do not run destructive commands such as `git reset --hard` or `git checkout -- <file>` unless the user explicitly asks.
- Do not use `git add -A`.

## Push

Push only the issue branch:

```powershell
git push -u origin fixbug-issue-{IssueNo}/{Owner}
```

If push is rejected because remote has new commits, stop and inspect. Do not force push unless the user explicitly instructs it and the branch ownership is clear.
