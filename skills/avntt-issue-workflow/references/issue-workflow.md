# Issue Workflow

Use this reference after selecting an issue source and target issue.

## Context Checklist

Before editing behavior, establish and say explicitly:

- Issue number.
- Branch name.
- Source CSV/XLSX row.
- `Issue Description (VN)`.
- `Dicussion item`.
- Existing issue note path, if any.
- Related screen/view/component.
- Current behavior observed from code or user evidence.
- Expected behavior from CSV, discussion, screenshot, worklog, or user confirmation.
- Files likely in scope.

## Brainstorming Gate

Use `superpowers:brainstorming` before changing behavior. If it is unavailable, ask the user to install/setup it or approve the fallback checklist.

During brainstorming:

- Restate the request in your own words.
- List 2-3 interpretations or fix approaches when ambiguity exists.
- Recommend one approach with trade-offs.
- Ask the user when the screen, field, button, popup, grid, expected behavior, or duplicate view scope is unclear.
- Do not guess business rules.

## Duplicate View Rule

If similar behavior exists in multiple files or views:

1. Search for duplicate components and patterns.
2. List all candidate files.
3. Explain whether they appear to share the same behavior.
4. Ask before applying synchronized edits.

Do not silently edit duplicate views just because names look similar.

## Stop Conditions

Stop before editing when:

- Current and expected behavior cannot be proven from source, CSV, worklog, screenshot, or user confirmation.
- More than one business interpretation is plausible.
- The required screen/view/component is unknown.
- A dirty/staged file in scope was not created by you and changes the same logic.
- The repo is in merge, rebase, or cherry-pick state.
- The issue branch is owned by another worktree and safe switching is unclear.

## Correction Flow

When the user asks to return to a completed issue:

- Treat it as a correction for that issue.
- Use the same issue branch when possible.
- Read previous commits, worklog, and issue note.
- Do not select the next issue.
- Verify the correction independently.
- Final response must mention it is a correction.
