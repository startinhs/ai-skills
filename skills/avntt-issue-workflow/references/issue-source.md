# Issue Source

Use this reference when locating and validating the user's issue source.

## Accepted Inputs

Prefer function-specific CSV files:

```text
Excel/ByFunction/<function-name>.csv
```

Also accept:

```text
Excel/<custom-source>.csv
Excel/<custom-source>.xlsx
```

If the user does not provide a source path, read `.codex-worklog/state.md` first and infer the current function and current issue. If inference is not possible, ask for the source path.

## Required Columns

The CSV/XLSX should contain these columns:

```csv
Issue No,Priority,Screen/Topic,Issue Description (VN),Dicussion item
```

Accept extra columns. Do not require exact column order. Preserve the misspelling `Dicussion item` because existing exports use it.

## Validation Cases

Stop and ask or report clearly when:

- The source file does not exist.
- The file is `.xlsx` and no spreadsheet-reading method is available.
- Vietnamese text appears corrupted because of encoding.
- Required columns are missing.
- The target `Issue No` is absent.
- The same `Issue No` appears multiple times with conflicting content.
- Worklog/progress says an issue is done but the user asks to continue it; treat it as a correction, not the next issue.
- Discussion references images/attachments that are not available.

## Selection Rules

- If the user names an issue, that issue wins over `Current Issue` in worklog.
- If the user says "next issue", use `.codex-worklog/state.md` and progress to select the next not-started issue.
- If the user says "go back to issue X", work on issue X and its branch even if progress marks it done.
- If CSV and progress conflict, explain the conflict and use the user's latest instruction when safe.
