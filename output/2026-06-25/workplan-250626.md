# Workplan — task250626.xlsx — 2026-06-25

Source: `.autoIssue/input/task250626.xlsx`  
Owner: `tinhlm`  
Base branch: `release/1.0.0-avntt-rc1`  
Branch format: `fixbug-issue-{IssueNo}/tinhlm`

## Thứ tự xử lý (Issue type trước, sau đó Request; High trước Medium)

| Order | Issue No | Type    | Priority | Screen/Topic                          | Branch                         | Status |
|-------|----------|---------|----------|---------------------------------------|--------------------------------|--------|
| 1     | 1648     | Issue   | High     | 9.UAT-Bán hàng trên Web (theo xe)    | fixbug-issue-1648/tinhlm       | Todo   |
| 2     | 1649     | Issue   | High     | 9.UAT-Bán hàng trên Web (theo xe)    | fixbug-issue-1649/tinhlm       | Todo   |
| 3     | 1609     | Request | High     | 8.UAT-Bán hàng trên App              | fixbug-issue-1609/tinhlm       | Todo   |
| 4     | 1413     | Request | Medium   | 9.UAT-Bán hàng trên Web (theo xe)    | fixbug-issue-1413/tinhlm       | Todo   |
| 5     | 1472     | Request | Medium   | 17.Integration-Master data            | fixbug-issue-1472/tinhlm       | Todo   |
| 6     | 1562     | Request | Medium   | 8.UAT-Bán hàng trên App              | fixbug-issue-1562/tinhlm       | Todo   |

---

## Chi tiết từng Issue

### [1] Issue 1648 — Issue / High
**Screen:** 9.UAT-Bán hàng trên Web (theo xe) > Hóa đơn điện tử  
**Branch:** `fixbug-issue-1648/tinhlm`  
**Mô tả:** Đơn hàng có CTKM PA → khi xuất hóa đơn thì hóa đơn hiển thị **sai số lượng quy đổi**. SO mẫu: `SO0000008170`  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1648/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1648/tinhlm
```

---

### [2] Issue 1649 — Issue / High
**Screen:** 9.UAT-Bán hàng trên Web (theo xe) > Hóa đơn điện tử  
**Branch:** `fixbug-issue-1649/tinhlm`  
**Mô tả:** Xem hóa đơn có trả CKTM → **hiển thị số âm ở ô Thuế**. SO mẫu: `SO0000008177`  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1649/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1649/tinhlm
```

---

### [3] Issue 1609 — Request / High
**Screen:** 8.UAT-Bán hàng trên App > Màn hình Dashboard  
**Branch:** `fixbug-issue-1609/tinhlm`  
**Mô tả:** Áp dụng cho KPI trên **Web và App** — Ẩn một số KPI không cần dùng, áp dụng cho KPI mới FY26 dùng cho Pilot. IT đã email 17/6/2026.  
**Note:** Cần xác nhận danh sách KPI nào cần ẩn (xem email IT 17/6/2026).  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1609/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1609/tinhlm
```

---

### [4] Issue 1413 — Request / Medium
**Screen:** 9.UAT-Bán hàng trên Web (theo xe) > Đơn hàng bán theo xe — Đơn hàng thay thế  
**Branch:** `fixbug-issue-1413/tinhlm`  
**Mô tả:** Hiện tại khi chọn đơn hàng thay thế → chọn mã PSI nhưng sau khi chọn xong **hiển thị mã SO** thay vì PSI. Yêu cầu: field "Đơn hàng thay thế" hiển thị mã PSI đã chọn cho đồng nhất, tránh sai sót.  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1413/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1413/tinhlm
```

---

### [5] Issue 1472 — Request / Medium
**Screen:** 17.Integration-Master data > Danh mục sản phẩm  
**Branch:** `fixbug-issue-1472/tinhlm`  
**Mô tả:** Cho phép tick đơn vị bán cho sản phẩm (đơn vị quy đổi) ở eSales một cách độc lập. AVN muốn có thể can thiệp trực tiếp trên eSales trong trường hợp urgent trước khi đơn hàng convert về SAP.  
**Note:** Cần xác nhận scope — có ảnh hưởng đến SAP sync logic không?  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1472/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1472/tinhlm
```

---

### [6] Issue 1562 — Request / Medium
**Screen:** 8.UAT-Bán hàng trên App > App - Báo cáo Kho  
**Branch:** `fixbug-issue-1562/tinhlm`  
**Mô tả:** Thứ tự sắp xếp sản phẩm trong **App - Báo cáo Kho** phải giống Báo cáo tồn kho cuối ngày.  
**Git commands:**
```powershell
git fetch origin release/1.0.0-avntt-rc1
git checkout release/1.0.0-avntt-rc1
git pull origin release/1.0.0-avntt-rc1
git checkout -b fixbug-issue-1562/tinhlm
# ... implement fix ...
git push -u origin fixbug-issue-1562/tinhlm
```

---

## Workflow chung (theo AVNTT Issue Workflow skill)

1. Đọc `.codex-worklog/state.md` + issue note trước khi bắt đầu
2. Sync `release/1.0.0-avntt-rc1` → tạo branch issue
3. Dùng `superpowers:brainstorming` phân tích yêu cầu trước khi sửa
4. Hỏi lại nếu thiếu view/field/expected behavior cụ thể
5. RED check trước fix, GREEN check sau fix
6. Thêm trace comment: `// Issue {No} | fixbug-issue-{No}/tinhlm | {commit-hash}`
7. Stage files cụ thể (KHÔNG dùng `git add -A`)
8. Commit theo Conventional Commits, không có attribution tag
9. Push branch issue lên origin
10. Cập nhật worklog local (KHÔNG commit worklog trừ khi được yêu cầu)
