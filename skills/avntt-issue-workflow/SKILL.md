---
name: avntt-issue-workflow
description: "Workflow for processing AVNTT project issues from Excel/CSV worklogs into isolated issue branches with mandatory requirement analysis, git safety, TDD/static verification, trace comments, commit/push rules, and local worklog updates. Use when fixing bugs or handling UAT issues in the HQSOFT Xspire AVNTT repo, especially requests that mention Excel issue files, .codex-worklog, issue branches, release/1.0.0-avntt-rc1, or function-specific CSV filters."
---

# AVNTT Issue Workflow

## Overview

Use this skill to process one AVNTT issue at a time from a user-provided Excel/CSV source and the repo worklog. The workflow is deliberately conservative: read context first, use one branch per issue, avoid `develop`, verify before claiming done, push only the issue branch, and leave user/unrelated changes untouched.

## Required Companion Skills

Before any bug fix or behavior change, use **`superpowers:brainstorming`** together with the **AVNTT devkit** (`/avntt-start` + relevant `/avntt-*` skills). The two must be used in combination:

1. **`/avntt-start`** (or the relevant `/avntt-*` skill) — loads domain context from `0.docs/`: triage tier/lane/gates, source-map routing, backend/frontend/DB rules, parity gates.
2. **`superpowers:brainstorming`** — analyzes the requirement *within* that loaded context: restates the issue, identifies ambiguities, lists options, and confirms scope before any edit.

Why both are required together:

- AVNTT devkit provides **where** to look (repo → module → file, gates to activate).
- Brainstorming provides **what** to do (restate issue, resolve ambiguities, confirm scope).
- Excel issues often omit exact fields, views, buttons, screenshots, or expected behavior — brainstorming catches this; the devkit supplies the domain rules to judge the options.
- Many screens have duplicated views; the source-map (devkit) identifies them; brainstorming confirms which ones to fix.
- Business behavior must not be guessed from weak evidence — both gates enforce this.

If either skill is not available:
- If `superpowers:brainstorming` is unavailable: use the fallback checklist (read CSV/worklog/issue notes, restate issue, identify screen/view/component, list current vs expected behavior, ask when ambiguous).
- If `/avntt-start` is unavailable: manually read `0.docs/AI-AGENT-ENTRY.md` → `TRIAGE-QUICK-DECISION.md` → `115-source-map/00-overview.md` before proceeding.

## Reference Map

Read these references as needed:

- `references/issue-source.md`: Excel/CSV inputs, required columns, encoding, mismatch cases.
- `references/issue-workflow.md`: end-to-end issue flow and stop conditions.
- `references/git-branching.md`: branch/worktree/base/push rules.
- `references/verification.md`: RED/GREEN, static checks, build, trace comments.
- `references/worklog.md`: `.codex-worklog` update rules and final reporting.
- `assets/issue-template.csv`: header-only issue CSV template.

## AVNTT Devkit (0.docs)

The workspace `0.docs/` is the canonical knowledge base. Read these before any domain-touching fix:

| File | Khi nào đọc |
|------|-------------|
| `0.docs/AI-AGENT-ENTRY.md` | Mọi task — entry point, read order, 4 gates |
| `0.docs/102-core-rules/TRIAGE-QUICK-DECISION.md` | Xác định tier · lane · repo/module · gates |
| `0.docs/102-core-rules/POLICY.md` | Proof-of-load header + chat protocol |
| `0.docs/102-core-rules/38-OFFLINE-PARITY-GATE.md` | Khi task đụng đơn/khách/KM/check-in/KPI |
| `0.docs/115-source-map/00-overview.md` | "Đổi gì → đi đâu" — định vị repo → module → file |
| `0.docs/115-source-map/01-task-routing.md` | Routing chi tiết theo loại thay đổi |
| `0.docs/120-backend/` | Quy tắc backend (entity, AppService, EF, .Extended.cs) |
| `0.docs/130-frontend/` | Quy tắc Blazor UI (DxGrid, pattern, component) |
| `0.docs/125-database/` | DB ground truth (PostgreSQL functions, schema per module) |
| `0.docs/160-sfa-mobile/` | SFA mobile (Flutter/Dart, BLoC, Riverpod) |
| `0.docs/165-offline/` | Offline mode spec + sync |
| `0.docs/170-promotion-engine/` | Promotion engine parity (Dart ↔ .NET) |
| `0.docs/180-integration/sap.md` | SAP integration (SOAP/SFTP) |

**Invoke `/avntt-start` at session start** to bootstrap the full devkit context (loads AI-AGENT-ENTRY + TRIAGE + source-map automatically). For domain-specific deep-dives use the per-domain `/avntt-*` skills:</p>

| Skill | Dùng khi |
|-------|----------|
| `/avntt-backend-entity` | Tạo/sửa entity, AppService, migration |
| `/avntt-blazor-screen` | Tạo/sửa màn hình Blazor |
| `/avntt-bug-fix` | Fix bug theo workflow 1.bugs/ |
| `/avntt-report-creation` | Tạo/sửa báo cáo .repx + fs_rp_* |
| `/avntt-sap-integration` | SAP SOAP/SFTP interfaces |
| `/avntt-offline-parity` | Offline parity gate check |
| `/avntt-promotion-parity` | Promotion engine Dart ↔ .NET |
| `/avntt-migration-psql` | EF migration + inject .psql |
| `/avntt-localization` | VI/EN language keys |

## Non-Negotiable Rules

- Work on exactly one `Issue No` per branch unless the user explicitly requests otherwise.
- Default base branch is `release/1.0.0-avntt-rc1`.
- Branch format: `fix/fix-{ShortDesc}-{IssueNo}-{Owner}` (with issue no.) or `fix/fix-{ShortDesc}-{Owner}` (without). Examples: `fix/fix-promotionDetail-1471-tinhlm`, `fix/fix-cktm-triple-tinhlm`. Default `{Owner}` = `tinhlm`.
- `{ShortDesc}` must be short, ASCII, no spaces: use camelCase or lowercase words separated by `-`.
- Infer `{Owner}` from the user's instruction, `.codex-worklog`, current branch, or existing remote/local branch. If still unknown, default to `tinhlm` or ask once.
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
11. Inspect diff for scope, stage files explicitly, commit using `references/commit-prompt.md`.
12. If trace comments require the fix commit hash, add/update those comments after the fix commit, rerun verification, and commit the trace update.
13. Push only the issue branch to origin.
14. Update local worklog/progress/issue note, but do not commit those files unless requested.
15. Final response must state issue, branch, commits, push status, verification, and untouched dirty files.

## Trace Comment Format

For every bugfix in a comment-capable source file, add a short trace comment near the corrected logic:

```csharp
// Issue 1371 | fix/fix-promotionDetail-1371-tinhlm | c3ae31bc4
// Keep detail audit records under the promotion header history.
```

Use the real issue number, branch owner, and fix commit hash in source comments. Because a commit hash cannot be embedded inside the same commit that creates it, use a second trace/comment commit when the user requires the hash in source.

If the changed file format does not support comments, do not break syntax. Record the trace in tests, worklog, or the nearest comment-capable source file that owns the behavior.

## Build Command

Default required build:

```powershell
dotnet build HQSOFT.Xspire.Application.sln -c Debug -p:WarningLevel=0 -p:NoWarn=NU1701%3BNU1608%3BNU1901%3BNU1902%3BNU1903%3BNU1904 -p:RunAnalyzers=false -m:4 -nodeReuse:false -tl
```
