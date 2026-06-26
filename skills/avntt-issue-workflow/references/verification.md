# Verification

Use this reference while implementing and before reporting completion.

## TDD Or Regression Baseline

Use `superpowers:test-driven-development` when adding a testable bugfix. At minimum, run a RED or baseline check before implementation:

- Existing failing test, if available.
- New focused regression test.
- Static scan that demonstrates the missing/wrong behavior.
- UI screenshot/manual reproduction note when automation is not practical.

If a RED test does not fail, the test has not proven the bug. Fix the test or choose another baseline.

## Green Checks

After implementation:

- Run the focused test/static check that covers the fix.
- Run related test class/project when practical.
- Inspect `git diff` for scope.
- Run the full build by default unless the user explicitly says not to.

Required build:

```powershell
dotnet build HQSOFT.Xspire.Application.sln -c Debug -p:WarningLevel=0 -p:NoWarn=NU1701%3BNU1608%3BNU1901%3BNU1902%3BNU1903%3BNU1904 -p:RunAnalyzers=false -m:4 -nodeReuse:false -tl
```

If the build is blocked by locked DLLs or a running user app, do not kill the user's process. Report the blocker or use an isolated build worktree if safe.

## Trace Comments

For every bugfix in comment-capable source, add a trace comment near the fixed logic:

```csharp
// Issue 1371 | fixbug-issue-1371/{Owner} | c3ae31bc4
// Keep detail audit records under the promotion header history.
```

Rules:

- Use the real issue, branch owner, and fix commit hash.
- Keep the second line focused on why the fix exists.
- Do not describe obvious code mechanics.
- Use the language/style valid for the file type.
- If comments are unsupported, do not break syntax; record the trace in tests or worklog.

Because a commit hash cannot be embedded in its own commit, default bugfix flow with hash comments is:

1. Implement fix and provisional trace comment without hash if needed.
2. Run RED/GREEN/build.
3. Commit the fix.
4. Capture the fix commit hash.
5. Update trace comments with the fix hash.
6. Rerun focused verification and full build by default.
7. Commit the trace/comment update.
8. Push the issue branch.

## Completion Gate

Do not say the issue is fixed until:

- Diff is scoped.
- Required checks have passed or skipped checks are explicitly reported.
- Commit(s) are created.
- Branch is pushed when the workflow requires push.
- Worklog is updated locally.
