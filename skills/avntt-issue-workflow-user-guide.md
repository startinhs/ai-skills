# AVNTT Issue Workflow Skill - User Guide

Tài liệu này dành cho người dùng Codex trong repo AVNTT khi xử lý issue từ Excel/CSV và `.codex-worklog`.

Skill repo-local:

```text
.codex/skills/avntt-issue-workflow
```

Tên skill để gọi trong prompt:

```text
$avntt-issue-workflow
```

## Skill này dùng để làm gì

Dùng skill này khi cần:

- Xử lý issue UAT/bug theo file Excel hoặc CSV.
- Đọc `.codex-worklog/state.md`, progress và issue note để tìm issue tiếp theo.
- Tạo branch riêng cho từng `Issue No`.
- Phân tích yêu cầu trước khi sửa behavior.
- Commit/push branch issue đúng workflow dự án.
- Cập nhật worklog local sau khi xong.

Skill không thay thế việc xác nhận nghiệp vụ. Nếu issue mơ hồ, agent phải hỏi lại.

## Chuẩn bị trước khi gọi skill

Cần có tối thiểu:

- Repo path, ví dụ: `C:\Users\HQsoft\Desktop\AVNTT\backendavn`
- Issue source, ví dụ: `Excel/ByFunction/3.UAT-Chương trình khuyến mãi.csv`
- Branch owner suffix, ví dụ: `toantv`, `duhk`, `tinhlm`
- Worklog/progress nếu đã có:
  - `.codex-worklog/state.md`
  - `.codex-worklog/functions/<function-slug>/progress.md`
  - `.codex-worklog/issues/issue-{IssueNo}.md`

Branch issue sẽ có format:

```text
fixbug-issue-{IssueNo}/{Owner}
```

Nếu chưa biết `{Owner}`, agent sẽ hỏi trước khi tạo/switch branch.

## Prompt khuyến nghị cho người mới

Dùng prompt này khi người dùng chưa quen workflow hoặc muốn agent báo cáo đầy đủ trước khi sửa.

```text
Use $avntt-issue-workflow.

Repo: <repo-path>
Issue source: <csv-or-xlsx-path>
Progress file: <progress-md-path>
Branch owner: <owner-suffix>

Tôi là người mới dùng workflow này.
Hãy xử lý issue tiếp theo theo đúng AVNTT issue workflow.

Yêu cầu:
- Trước khi sửa code, hãy nói rõ issue đang làm, branch sẽ dùng, source CSV row, màn hình/view liên quan, current behavior, expected behavior, file scope.
- Nếu thiếu thông tin hoặc có nhiều cách hiểu, hãy hỏi tôi trước. Không đoán nghiệp vụ.
- Dùng superpowers:brainstorming trước khi sửa behavior.
- Rà duplicate view/file liên quan và hỏi trước khi sửa đồng bộ.
- Chạy RED/GREEN hoặc static regression check.
- Build mặc định trước commit/push.
- Thêm trace comment cho bugfix theo format Issue | branch | commit hash.
- Commit/push branch issue, không dùng develop.
- Update worklog local, không commit worklog/Excel nếu tôi không yêu cầu.
```

## Prompt ngắn cho người đã quen

Dùng prompt này khi đã biết workflow, nhưng vẫn nên điền đủ `Repo`, `Issue source` và `Branch owner`.

```text
Use $avntt-issue-workflow.

Repo: <repo-path>
Issue source: <csv-or-xlsx-path>
Branch owner: <owner-suffix>

Làm issue tiếp theo theo state/progress.
Tuân thủ AVNTT workflow: release base, one issue/branch, brainstorming trước khi sửa, hỏi nếu thiếu expected behavior, rà duplicate view, RED/GREEN hoặc static check, build trước commit/push, trace comment, push issue branch, update worklog local.
```

## Prompt cực ngắn cho session đã có context

Chỉ dùng khi cùng session đã xác định rõ repo, source issue, branch owner và state/progress đang đúng.

```text
Use $avntt-issue-workflow. Làm issue tiếp theo theo state/progress hiện tại.
```

Không nên dùng prompt cực ngắn ở session mới vì agent có thể thiếu `Issue source` hoặc `{Owner}`.

## Làm issue cụ thể

Dùng khi không muốn lấy issue tiếp theo.

```text
Use $avntt-issue-workflow.

Repo: <repo-path>
Issue source: <csv-or-xlsx-path>
Issue No: <issue-no>
Branch owner: <owner-suffix>

Hãy xử lý đúng issue này, không lấy issue tiếp theo.
Tuân thủ workflow AVNTT issue branch, brainstorming, verification, trace comment, commit/push, và worklog local.
```

## Quay lại correction issue đã done

Dùng khi issue đã xong nhưng cần sửa tiếp theo feedback UI/review.

```text
Use $avntt-issue-workflow.

Repo: <repo-path>
Issue No: <issue-no>
Branch: fixbug-issue-<issue-no>/<owner-suffix>

Đây là correction cho issue đã done.
Đọc lại issue note, commits cũ, CSV/worklog nếu cần.
Phân tích bằng superpowers:brainstorming trước khi sửa.
Không chọn issue tiếp theo.
```

## Việc agent sẽ làm

Khi prompt đủ thông tin, agent sẽ:

1. Đọc state/progress và issue note nếu có.
2. Đọc row của issue trong CSV/XLSX.
3. Kiểm tra git status, staged files và worktree.
4. Sync `release/1.0.0-avntt-rc1`.
5. Tạo/switch branch `fixbug-issue-{IssueNo}/{Owner}`.
6. Dùng `superpowers:brainstorming` để phân tích yêu cầu.
7. Hỏi lại nếu thiếu view, field, button, popup, grid hoặc expected behavior.
8. Chạy RED/GREEN hoặc static regression check.
9. Sửa code trong scope nhỏ nhất.
10. Thêm trace comment cho bugfix nếu file hỗ trợ comment.
11. Build mặc định trước commit/push, trừ khi user nói rõ không build.
12. Commit theo `.copilot/prompt/commit-prompt.md`.
13. Push branch issue lên origin.
14. Update worklog local và không commit worklog/Excel nếu user không yêu cầu.

## Trace comment

Mỗi bugfix trong file có hỗ trợ comment nên có trace comment gần logic đã sửa:

```csharp
// Issue 1371 | fixbug-issue-1371/toantv | c3ae31bc4
// Keep detail audit records under the promotion header history.
```

Nếu owner khác thì branch trong comment phải đúng owner đó, ví dụ:

```csharp
// Issue 1371 | fixbug-issue-1371/duhk | c3ae31bc4
// Keep detail audit records under the promotion header history.
```

Vì commit hash không thể nằm trong chính commit tạo ra nó, agent có thể tạo thêm một commit trace/comment sau khi đã có hash fix commit.

## Prompt không nên dùng

Tránh các prompt mơ hồ nếu session mới chưa có context:

```text
làm tiếp đi
```

```text
fix bug này
```

```text
A đi
```

Nếu cần dùng prompt ngắn, hãy đảm bảo session đã có sẵn repo, issue source, owner và issue đang bàn.

## Troubleshooting

Nếu agent hỏi lại `Branch owner suffix`, hãy trả lời bằng tên owner đúng trong branch, ví dụ:

```text
duhk
```

Nếu CSV không đọc được tiếng Việt, hãy kiểm tra encoding hoặc export lại CSV UTF-8.

Nếu issue có nhiều view/file giống nhau, agent sẽ liệt kê candidate files và hỏi trước khi sửa đồng bộ.

Nếu build bị lock DLL do app đang chạy, agent không được kill process của user. Agent sẽ báo rõ blocker hoặc dùng worktree riêng nếu an toàn.

Nếu không có `superpowers:brainstorming`, agent phải hỏi user muốn setup/cài đặt skill hay dùng fallback checklist cho session đó.
