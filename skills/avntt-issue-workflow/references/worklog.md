# Worklog

Use this reference when reading or updating `.codex-worklog`.

## Read First

Read these before choosing or editing an issue:

```text
.codex-worklog/state.md
.codex-worklog/functions/<function-slug>/progress.md
.codex-worklog/issues/issue-{IssueNo}.md
```

If paths are missing, infer what you can from the repo and ask only when selection is unsafe.

## Update After Done

After verification, commit, and push, update locally:

```text
.codex-worklog/state.md
.codex-worklog/functions/<function-slug>/progress.md
.codex-worklog/issues/issue-{IssueNo}.md
```

Include:

- Issue number and branch.
- Status.
- Commit hash(es).
- Push destination.
- Summary of behavior changed.
- Tests/static checks/build results.
- Any user confirmation or ambiguity resolved.

## Commit Rule

Do not stage or commit `.codex-worklog/` unless the user explicitly asks.

If the user asks to commit worklog, stage only the specific worklog files and make that decision visible in the final response.

## Final Response Checklist

Final response should include:

- Issue number.
- Branch.
- Commit hash(es).
- Push status.
- Files changed at a high level.
- Verification commands/results.
- Worklog updated locally and not committed, if applicable.
- Unrelated dirty files left untouched.
