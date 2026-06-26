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

## Branch Format

```text
fix/fix-{ShortDesc}-{IssueNo}-{Owner}   ← khi có mã issue
fix/fix-{ShortDesc}-{Owner}             ← khi không có mã issue
```

**Rules:**
- `{ShortDesc}` — tên ngắn gọn mô tả nội dung fix, ASCII, không dấu cách; dùng camelCase hoặc lowercase words nối bằng `-`. Ví dụ: `promotionDetail`, `cktm-triple`, `sapClearLine`.
- `{IssueNo}` — mã số issue (3–4 chữ số). Bỏ qua nếu không có mã issue.
- `{Owner}` — username của người fix. Mặc định: `tinhlm`.

**Examples:**
```text
fix/fix-promotionDetail-1471-tinhlm  ← có mã issue 1471
fix/fix-cktm-triple-tinhlm           ← không có mã issue
fix/fix-invoicePAQty-1648-tinhlm
```

Resolve `{Owner}` before creating or switching branches:

- Use the owner explicitly provided by the user.
- Otherwise infer it from `.codex-worklog`, the current branch, an existing local branch, or an existing remote branch for the same fix.
- If no owner can be inferred, default to `tinhlm` or ask once.
- After `{Owner}` is resolved, reuse it consistently in branch name, push command, trace comments, and worklog.

If the branch exists locally, switch to it after verifying it is not held by another worktree.

If the branch exists on origin but not locally:

```powershell
git fetch origin fix/fix-{ShortDesc}-{IssueNo}-{Owner}
git checkout -b fix/fix-{ShortDesc}-{IssueNo}-{Owner} origin/fix/fix-{ShortDesc}-{IssueNo}-{Owner}
```

If there is no issue number, omit `-{IssueNo}` in the commands.

If the branch does not exist:

```powershell
git checkout -b fix/fix-{ShortDesc}-{IssueNo}-{Owner}
```

If there is no issue number, use `fix/fix-{ShortDesc}-{Owner}`.

## Forbidden

- Do not use `develop` as a base.
- Do not pull, merge, or cherry-pick from `develop`.
- Do not push or merge into `develop`.
- Do not run destructive commands such as `git reset --hard` or `git checkout -- <file>` unless the user explicitly asks.
- Do not use `git add -A`.

## Push

Push only the fix branch:

```powershell
git push -u origin fix/fix-{ShortDesc}-{IssueNo}-{Owner}
```

If there is no issue number, push `fix/fix-{ShortDesc}-{Owner}`.

If push is rejected because remote has new commits, stop and inspect. Do not force push unless the user explicitly instructs it and the branch ownership is clear.
