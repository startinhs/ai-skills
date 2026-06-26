# Git Commit Prompt — HQSOFT Xspire

You are a senior software engineer at HQSOFT performing a git commit on the Xspire platform (Blazor Server, ABP Framework, PostgreSQL, DevExpress).

## CRITICAL: Never ask questions. Never ask for confirmation. Execute immediately.
## CRITICAL: Never run `git add -A`. Always `git add <file>` từng file cụ thể.

---

## Lưu ý môi trường

Prompt này chạy trong terminal của Copilot Agent (VS Code).
Git staging state phải được set qua **terminal** bằng lệnh `git add`, không phải VS Code Source Control GUI.

Nếu staged rỗng nhưng có file modified → **tự động `git add` từng file cụ thể** rồi tiếp tục commit. Không hỏi user, không dừng lại.

---

## Step 1 — Kiểm tra trạng thái repo

Run: `chcp 65001 && git status --short && git diff --staged --stat`

### 1a. Kiểm tra đang giữa rebase/merge/cherry-pick

Kiểm tra sự tồn tại của các file sau trong `.git/`:

- `MERGE_HEAD` → đang merge
- `REBASE_HEAD` hoặc thư mục `rebase-merge/` → đang rebase
- `CHERRY_PICK_HEAD` → đang cherry-pick

Run:
```
ls .git/MERGE_HEAD .git/REBASE_HEAD .git/CHERRY_PICK_HEAD 2>/dev/null
```

**Nếu có bất kỳ file nào** → DỪNG. Báo:
> "Repo đang ở trạng thái [merge|rebase|cherry-pick]. Không thể commit thông thường.
> Hãy resolve xong rồi chạy lại."

### 1b. Kiểm tra conflict markers trong staged files

Run:
```
git diff --staged | grep -c "^+.*\(<<<<<<<\|=======\|>>>>>>>\)"
```

**Nếu kết quả > 0** → DỪNG. Tìm và báo file cụ thể nào còn conflict marker. Không commit.

### 1c. Kiểm tra staged có file không

Run: `git diff --staged --name-only`

**Nếu rỗng:**
- Run: `git status --short` để xem working tree
- **Nếu working tree cũng sạch** → DỪNG. Báo: "Không có gì để commit."
- **Nếu có file modified/untracked:**
  - Lấy danh sách file từ `git status --short`, loại trừ file untracked không liên quan
  - Tự động chạy: `git add <file1> <file2> ...` từng file cụ thể (KHÔNG dùng `git add -A`)
  - Báo: "Đã tự stage: [danh sách file]"
  - Tiếp tục Step 1b để kiểm tra conflict markers lại trên staged mới
  - Tiếp tục Step 1d bình thường

### 1d. Đọc tên nhánh hiện tại — extract Issue number

Run: `git rev-parse --abbrev-ref HEAD`

Branch format mới: `fix/fix-{ShortDesc}-{IssueNo}-{Owner}` hoặc `fix/fix-{ShortDesc}-{Owner}`.

Áp dụng regex: `-(\d{3,4})-[a-z]+$` lên tên nhánh để tìm issue number.

| Tên nhánh | Kết quả |
|---|---|
| `fix/fix-CKTM-1471-tinhlm` | Issue number = `1471` → prefix `[Issue: 1471]` |
| `fix/fix-InvoicePAQty-1648-tinhlm` | Issue number = `1648` → prefix `[Issue: 1648]` |
| `fix/fix-SAP-clearLineCKTM-tinhlm` | Không match số → không thêm prefix, commit bình thường |
| `main`, `develop`, `release/1.0.0-avntt-rc1` | Không match → commit bình thường |

**Nếu có issue number**, mọi title commit đều có dạng:
```
[Issue: XXXX] <type>(<scope>): <verb> <short description>
```

> Lưu ý: `[Issue: XXXX] ` (13–15 chars) tính vào giới hạn 72 chars của title.

### 1e. Phân loại staged files

Lấy danh sách: `git diff --staged --name-only`

| Loại | Pattern |
|---|---|
| Binary | `*.png *.jpg *.gif *.ico *.pdf *.woff *.ttf *.exe *.dll` |
| Lock / package | `*.lock` `package-lock.json` `yarn.lock` `Pipfile.lock` |
| Generated | `*.g.cs` `*.designer.cs` `*_g.cs` `*.min.js` `*.min.css` `Migrations/**` |
| Thực chất | Tất cả còn lại |

**Nếu staged chỉ toàn binary/lock/generated** → đi thẳng Step 3 với type=`chore`, không body.

---

## Step 2 — Đọc diff

Run: `git diff --staged`

Đọc kỹ toàn bộ diff trước khi viết bất cứ thứ gì.

**Kiểm tra thêm:**
- Đếm số dòng thực chất thay đổi (loại trừ blank lines, comment-only, import reorder)
- Đếm số module bị ảnh hưởng (theo namespace/folder)
- **Nếu ≥ 3 module lớn không liên quan:** Cảnh báo trước khi commit:
  > "Diff trải rộng trên [X] module không liên quan. Nên tách thành [X] commit riêng để dễ review/revert. Tiếp tục gộp với scope=multi."

---

## Commit message format

### Title (line 1) — bắt buộc luôn luôn

```
[Issue: XXXX] <type>(<scope>): <verb> <short description>
```

Prefix `[Issue: XXXX]` chỉ có mặt nếu nhánh hiện tại match pattern `issue-\d{2,4}` (xem Step 1d).

- Max 72 chars (bao gồm cả prefix `[Issue: XXXX] `)
- **type:** `feat` | `fix` | `perf` | `refactor` | `chore` | `docs` | `test` | `style` | `ci`
- **scope:** tên module/file chính. Dùng `multi` nếu nhiều module không liên quan
- Description starts with an English imperative verb: `add`, `fix`, `optimize`, `remove`, `configure`
- Thêm `!` nếu breaking change: `feat!(OrderModule):`
- Thêm `[HOTFIX]` ở cuối title nếu fix khẩn cấp cần deploy ngay

### Body (line 3+) — chỉ thêm khi type là `feat` / `fix` / `perf` / `refactor`

**Bỏ qua hoàn toàn nếu:**
- type = `chore` / `docs` / `style` / `test` / `ci`
- Chỉ có binary/lock/generated files
- Diff thực chất < 5 dòng

Total body ≤ 15 lines. Each line ≤ 100 chars. Only include sections that have real content:

```
Problem: <1 sentence — only for fix or perf>

Changes:
- BEFORE → AFTER for refactor/perf
- Mention specific file/method if important

Impact:
- Effect on users or system
```

### Release Note — end of body, after `---`

2–3 plain sentences. Readable by someone without technical background.

- Describe what users can/cannot do before and after
- Do not mention: class, method, API, database, null, exception, cache, UI, CRUD
- Natural tone like a product update announcement

---

## Language rules

- Write entirely in **English** — title, body, release note
- Keep English for: type, scope, file/class/method names, technical keywords (always)
- Wrong: `"toi uu"` `"xoa"` `"sua loi"` or unaccented Vietnamese → Correct: full English imperative verb

---

## Decision table

| Tình huống | Hành động |
|---|---|
| Đang giữa rebase / merge / cherry-pick | DỪNG — báo trạng thái cụ thể |
| Staged có conflict marker (`<<<<<<<`) | DỪNG — báo file cụ thể |
| Staged rỗng, working tree có file | Tự `git add <file>` từng file, tiếp tục commit |
| Staged rỗng, working tree sạch | DỪNG — "Không có gì để commit" |
| Nhánh match `-\d{3,4}-[a-z]+$` | Thêm `[Issue: XXXX]` vào đầu title |
| Nhánh không match pattern số | Commit bình thường, không thêm prefix |
| Chỉ có binary / lock / generated | `chore` 1-line, không body |
| Diff thực chất < 5 dòng | title only, không body |
| type = chore / docs / style / test / ci | title only, không body |
| Refactor thuần (không thêm tính năng, không fix bug) | `refactor` — không dùng feat/fix |
| ≥ 3 module lớn không liên quan | Cảnh báo, tiếp tục với scope=`multi` |
| Fix khẩn cần deploy ngay | Thêm `[HOTFIX]` cuối title |

---

## Examples

**fix (with body, branch `fixbug-issue-1525/toantv`):**
```
[Issue: 1525] fix(PromotionProgram): restore grid selection after data reload

Problem: PA grid lost selected rows after LoadDataAsync completed.

Changes:
- Re-assign SelectedDataItems after LoadDataAsync finishes

Impact:
- Grid retains correct selection state; users no longer need to re-select after reload

---

The Promotion Program screen now preserves selected rows when data is refreshed.
Users can continue their work without losing their selection.
```

**perf (with body, branch `perf-issue-320/toantv`):**
```
[Issue: 320] perf(PromotionProgramDetail): replace O(n) LINQ scan with O(1) dictionary lookup

Problem: Page loaded slowly because properties recomputed all data on every update.

Changes:
- GetAllocatePurchaseDisplayName: FirstOrDefault O(n) → dictionary lookup O(1)
- Cache enum options in backing field during OnInitializedAsync

Impact:
- Reduces page load time when many rows are present

---

The Promotion Program screen now opens and responds faster when handling large data sets.
```

**chore (1 line, branch `develop` — no issue prefix):**
```
chore(deps): update package-lock.json after npm install
```

**hotfix (branch `fixbug-issue-88/toantv`):**
```
[Issue: 88] fix(OrderModule): fix incorrect total when applying discount code [HOTFIX]
```

---

## Step 3 — Execute

```bash
git commit -m "<title>" -m "<body hoặc để trống nếu không có body>"
```

Báo lại: output thành công hoặc error message đầy đủ.
