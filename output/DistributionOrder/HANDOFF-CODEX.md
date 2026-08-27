# Prompt bàn giao cho Codex — Implement 13 issue Đơn hàng NPP

> **Phân tích bởi:** Claude Opus session `d31e4e15-3c70-4124-92b6-870cee2542a4` (2026-08-27)
> **Trạng thái:** Phân tích xong, **chưa sửa file nào** trong `backendavn`.
> **Copy toàn bộ phần trong khung dưới đây làm prompt cho Codex.**

---

## PROMPT — copy từ đây

Bạn implement fix cho tính năng **Đơn hàng NPP (Distribution Order)** trong repo `D:\PROJECTS\Xspire_AVN\backendavn`.

### Bước 0 — Đọc trước khi làm bất cứ gì

Đọc theo đúng thứ tự:

1. `D:\PROJECTS\Xspire_AVN\ai-skills\output\DistributionOrder\README.md` — index + kết luận + thứ tự ưu tiên
2. `D:\PROJECTS\Xspire_AVN\ai-skills\output\DistributionOrder\01-issue-analysis.md` — **tài liệu chính**, nguyên nhân gốc từng issue kèm `file:line`
3. `D:\PROJECTS\Xspire_AVN\ai-skills\output\DistributionOrder\00-blueprint-analysis.md` — quy tắc nghiệp vụ gốc từ Blueprint v0.5
4. `D:\PROJECTS\Xspire_AVN\ai-skills\output\DistributionOrder\issues-npp.csv` — 13 issue theo schema `avntt-issue-workflow`
5. `D:\PROJECTS\Xspire_AVN\ai-skills\skills\AGENTS.md` — 13 rule bắt buộc của project
6. `D:\PROJECTS\Xspire_AVN\ai-skills\skills\avntt-issue-workflow\SKILL.md` + toàn bộ `references/`

Phân tích nguyên nhân gốc **đã xong và đã đối chiếu source code**. Không phân tích lại từ đầu — nhưng **phải verify lại `file:line` trước khi sửa**, vì số dòng có thể lệch nếu repo đã đổi.

### Bối cảnh quan trọng

- Đây **KHÔNG phải tính năng viết mới**. Cả 4 màn hình đã implement xong, đang ở giai đoạn hoàn thiện SIT/UAT.
- Đơn NPP **dùng chung** entity `SalesOrder` + `SalesOrderAppService.Extended.cs` với SalesOrders, phân biệt bằng loại đơn.
- UI dùng chung **một component** `Components/OrderManagement/DistributorOrderForm.razor(.cs)` cho **cả** màn "Đơn đặt hàng NPP" lẫn "Duyệt đơn đặt hàng NPP", qua tham số `IsApproveScreen`. Sửa component này ảnh hưởng **cả hai màn** — luôn kiểm tra cả 2 nhánh.

### Phạm vi được giao TRONG ĐỢT NÀY

Chỉ làm **4 issue** dưới đây, theo đúng thứ tự:

| Thứ tự | Issue | Mức độ | Nội dung |
|:---:|:---:|---|---|
| 1 | **#1 + #2** | Critical | Routing NPP thuộc đội — 1 sửa giải quyết cả hai |
| 2 | **#8 (chỉ phần D2)** | Critical | Bỏ `StackTrace` khỏi message import lỗi hiển thị cho user |
| 3 | **#10** | Medium | Ẩn nút "Xem trước" khi đơn trạng thái Huỷ |
| 4 | **#12** | Critical | Đổi ngày đặt hàng phải bắt tính lại giá/KM khi Lưu |

**KHÔNG làm** trong đợt này (đã có lý do cụ thể):

| Issue | Lý do hoãn |
|:---:|---|
| #7 | Có phần **phát triển mới** (popup + model + validate). Ba nguồn BP 4.2 / BP 4.3 / tracker đang **mâu thuẫn** về màn hình áp dụng. Chờ user chốt câu Q1. |
| #13, #3 | Là **chính sách phân quyền**, cần user quyết giữa "cấp/thu hồi quyền" (cấu hình) và "thêm quyền `Approve` riêng" (sửa code). Chờ Q4, Q5. |
| #4, #6 | Cần chốt dùng chung report DC hay report riêng. Chờ Q3. |
| #5, #11 | Chưa xác định được nguyên nhân gốc từ đọc code; cần reproduce + debug browser trước. |
| #9 | Cần reproduce để chốt giữa 3 giả thuyết N1/N2/N3; nếu là N1 thì phải xem lại transaction boundary chứ không chỉ đổi thứ tự dòng. |

Nếu làm xong 4 issue trên mà chưa có câu trả lời cho Q1/Q3/Q4/Q5 (phụ lục cuối `01-issue-analysis.md`) thì **dừng lại và báo cáo**, đừng tự suy diễn rồi làm tiếp.

### Quy tắc bắt buộc (từ AGENTS.md + avntt-issue-workflow)

- **Mỗi issue một branch riêng.** Base branch: `release/1.0.0-avntt-rc1`. Format: `fix/fix-{ShortDesc}-{IssueNo}-{Owner}`, `{Owner}` mặc định `tinhlm`. Ví dụ: `fix/fix-distributorOfTeamRoute-1-tinhlm`.
  - Riêng #1 và #2 cùng nguyên nhân gốc ⇒ được phép **một branch chung**, nhưng phải nói rõ trong commit message là fix cả 2 issue.
- **Không bao giờ** pull/merge/push/base lên `develop`.
- **Không** `git add -A`. Stage từng file cụ thể.
- **Không** commit `.codex-worklog/` hoặc `Excel/`.
- Giữ nguyên các file dirty/untracked không liên quan. Không revert thay đổi của user.
- **Rule 13 — KHÔNG chạy `dotnet build`.** User sẽ tự build sau khi review.
- **Rule 3 — Surgical.** Chỉ sửa đúng chỗ cần. Không refactor code lân cận, không sửa comment/format của hàm bên cạnh.
- **Rule 12 — Fail loud.** Bỏ qua bước nào phải nói rõ. Không báo "xong" nếu còn phần chưa làm.

### Trace comment bắt buộc

Mọi bugfix trong file có hỗ trợ comment phải thêm trace comment gần logic đã sửa:

```csharp
// Issue 10 | fix/fix-hidePreviewOnCancelled-10-tinhlm | <commit-hash>
// Ẩn nút Xem trước đơn đặt hàng khi đơn ở trạng thái Huỷ, khớp với instance màn duyệt.
```

Vì không thể nhúng hash vào chính commit tạo ra nó ⇒ dùng **commit thứ hai** cho phần trace.

---

## Chi tiết từng issue

### [1] Issue #1 + #2 — Routing NPP thuộc đội · Critical

**Triệu chứng:** Nút "Tạo mới" không làm gì; click mã chứng từ không mở được chi tiết.

**Nguyên nhân gốc — lệch số nhiều/số ít:**

| Vị trí | Giá trị hiện tại |
|---|---|
| `src\HQSOFT.Xspire.Application.Blazor\Pages\MasterData\DistributorOfTeam\DistributorOfTeamListView.razor.cs:70` | `ListUrl => "/MasterData/DistributorOfTeam` **`s`** `"` ← số nhiều |
| `...\DistributorOfTeamListView.razor:1` | `@page "/MasterData/DistributorOfTeam/"` ← số ít |
| `...\DistributorOfTeam.razor:1` | `@page "/MasterData/DistributorOfTeam/{Id}"` ← số ít |

`OpenEditTab` ghép `$"{baseUrl}/{id}"` → điều hướng tới route không tồn tại → catch nuốt lỗi (`HQSOFTRouterTabsService.cs:4732`) → nút "im lặng". `GotoEditPage` (`:676-679`) dùng cùng `ListUrl` ⇒ đó là Issue #2.

**Cách sửa — chọn Phương án A (đúng convention codebase):**

Đổi 2 route sang số nhiều:
- `DistributorOfTeamListView.razor:1` → `@page "/MasterData/DistributorOfTeams"`
- `DistributorOfTeam.razor:1` → `@page "/MasterData/DistributorOfTeams/{Id}"`

**BẮT BUỘC sửa kèm:** `DistributorOfTeam.razor.cs:318` đang hardcode **số ít**:
```csharp
HQSOFTRouterTabsService.OpenNewOrDuplicateTab("/MasterData/DistributorOfTeam", Guid.Empty, false, NavigationManager);
```
→ đổi sang số nhiều. **Bỏ sót dòng này sẽ làm hỏng nút "New" trên màn chi tiết (hiện đang chạy đúng).**

Đối chiếu màn chạy đúng cùng thư mục: `SalesTeamListView.razor.cs:39` + `SalesTeamListView.razor:1` + `SalesTeam.razor:1` — cả ba đều số nhiều.

**Sửa kèm cho #2 — defect bậc 2:**

`DistributorOfTeamListView.razor:174-189` — hyperlink chỉ render khi `row.DocumentCode != null`, nội dung thẻ `<a>` là `TruncateText(row.DocumentCode, 20)` (trả `string.Empty` khi rỗng, `:668-672`). Dòng có `DocumentCode` **rỗng** sẽ render `<a>` không nội dung ⇒ **không có vùng bấm**. Sau khi sửa route, dòng đó **vẫn** không click được.

→ Render placeholder (ví dụ `(chưa có mã)`) hoặc chuyển hyperlink sang cột chắc chắn có giá trị. Đích đến `row.Id` đã đúng, chỉ vùng bấm bị rỗng.

**Verify:** Tạo mới mở tab chi tiết rỗng · Click mã chứng từ mở đúng line · Dòng mã rỗng mở được chi tiết · Nút New trên màn chi tiết vẫn chạy · `MarkListViewNeedsRefresh` / `CloseEditTabsForDeletedEntities` / `UpdateListViewTabTitle` (`:258`, `:259`, `:106-109`) hoạt động trở lại.

---

### [2] Issue #8 phần D2 — Bỏ StackTrace khỏi message lỗi import · Critical

**Chỉ làm phần D2 trong đợt này.** Các phần D1/D3/D4/D5 và nguyên nhân dữ liệu để lại chờ user chốt Q6.

**Triệu chứng:** Popup import lỗi hiển thị nguyên `ex.StackTrace` — lộ đường dẫn source + số dòng ra người dùng, và che mất thông báo lỗi thật.

**Vị trí:** `modules\hqsoft.xspire.ordermanagement\src\HQSOFT.Xspire.OrderManagement.Application\SalesOrders\SalesOrderAppService.Extended.cs:8062` — nơi append `ex.StackTrace` vào danh sách lỗi hiển thị cho user (trong catch per-group `:8057-8063`).

**Cách sửa:** bỏ `StackTrace` khỏi message trả về UI. Vẫn **giữ** stack trace trong log phía server (`Logger.LogError(ex, ...)`) để còn debug được.

**Không đụng** vào khối validate `:8436-8451` hay logic đọc `customerCode` `:7915-7924` trong đợt này.

**Verify:** Import file lỗi → popup chỉ hiển thị message nghiệp vụ sạch, không có đường dẫn file/số dòng. Log server vẫn còn stack trace đầy đủ.

---

### [3] Issue #10 — Ẩn nút Xem trước khi đơn Huỷ · Medium

> **Lưu ý:** tracker ghi cột Màn hình là *"NPP thuộc đội"* nhưng ảnh chụp là màn **Đơn hàng nhà phân phối** (chi tiết `eSO000000104`, trạng thái `Huỷ`). Xử lý theo **ảnh chụp**.

**Nguyên nhân — điều kiện hiển thị không đồng nhất giữa 2 instance của cùng component:**

| Instance | Dòng | Điều kiện hiện tại |
|---|:---:|---|
| Màn **Duyệt đơn** | `DistributorOrderForm.razor.cs:386` | `EditingDocId != Guid.Empty && EditingDoc.Status != "Huỷ"` ← **đã đúng** |
| Màn **Đơn hàng NPP** | `DistributorOrderForm.razor.cs:507` | `EditingDocId != Guid.Empty` ← **thiếu** chặn Huỷ |

**Cách sửa:** thêm `&& EditingDoc.Status != "Huỷ"` vào `:507` cho khớp `:386`.

⚠ **Chuỗi trạng thái:** code dùng `"Huỷ"` (dấu **ngã**), Blueprint viết `Hủy` (dấu **hỏi**). **Copy đúng chuỗi từ `:386`, tuyệt đối không gõ lại bằng tay.**

**Verify:** Mở đơn trạng thái Huỷ ở màn Đơn hàng NPP → nút "Xem trước đơn đặt hàng" **ẩn**. Đơn trạng thái khác → nút vẫn hiện. Màn Duyệt đơn giữ nguyên hành vi cũ.

---

### [4] Issue #12 — Đổi ngày đặt hàng phải bắt tính lại giá/KM · Critical

**Kết quả mong muốn (nguyên văn tracker):** khi Lưu, hiển thị *"Vui lòng tính lại giá và khuyến mại do có sự thay đổi ngày đặt hàng"* và **giữ nguyên trạng thái** đơn hàng.

**Cờ trạng thái sẵn có:** `EditingDoc.IsPromotion` (bool trên `SalesOrderUpdateDto`), nhãn UI "Đã tính khuyến mại" — `DistributorOrderForm.razor:297-302`. Không tồn tại property `IsPromotionCalculated` nào khác; `IsPromotion` đảm nhiệm vai trò này.

**Vì sao lọt qua — 4 nguyên nhân:**

1. **Editor không invalidate cờ.** `DistributorOrderForm.razor:182-186`:
```razor
DateChanged="@(async(DateTime newValue) => {
    EditingDoc.OrderDate  = newValue;
    EditingDoc.RecordDate = newValue;
    await MarkAsChanged(true);
})"
```
Chỉ đánh dấu dirty — **không** clear `EditingDoc.IsPromotion`, **không** ép tính lại giá.

2. **Guard chỉ nằm trong `CalculatePromotions()`.** `DistributorOrderForm.razor.cs:3715-3723` có sẵn:
```csharp
var hasRecordDateChanged = _originalRecordDate.HasValue && _originalRecordDate.Value != EditingDoc.RecordDate;
if ((hasRecordDateChanged || hasIsPrices || HasChangeds))
{
    await UiMessageService.Warn(L["Bạn cần tính lại giá"]);
    return;
}
```
Nhưng `SaveDataNewAsync` (`:835`) và `SaveDataAsync` (`:1007`) **không** có check này.

3. **Bằng chứng bị xoá trên đường create.** `SaveDataNewAsync:915` gán `EditingDoc.RecordDate = EditingDoc.OrderDate;` — reload sau đó capture lại `_originalRecordDate`, xoá mất dấu vết guard dựa vào.

4. **Cổng duyệt chỉ hỏi "đã từng tính chưa".** `:432-436` và `:584` chỉ check `!EditingDoc.IsPromotion`, không hỏi "đã tính cho ĐÚNG ngày hiện tại chưa".

**Biến sẵn có:** `_originalRecordDate` — khai báo `:6051`, capture lúc load `:2243`/`:2295`, reset `:1494`/`:1961`/`:5317`.

**Cách sửa — 3 lớp, làm cả 3:**

1. **Invalidate tại nguồn:** trong `DateChanged` của "Ngày đặt hàng" (`DistributorOrderForm.razor:182-186`), set `EditingDoc.IsPromotion = false` và đánh dấu giá không còn hợp lệ.
2. **Guard tại Save:** thêm check `hasRecordDateChanged` vào `SaveDataNewAsync` và `SaveDataAsync`, hiển thị **đúng** message user yêu cầu, và **giữ nguyên trạng thái đơn** (không đổi status).
3. **Xem lại `SaveDataNewAsync:915`:** cân nhắc thứ tự gán `RecordDate` để không xoá mất `_originalRecordDate` trước khi guard kịp chạy.

⚠ **CẢNH BÁO — không copy mẫu từ SalesOrder.** `Pages\OrderManagement\SalesOrder\SalesOrder1.razor.cs:6711` tính **đúng biểu thức** `hasRecordDateChanged` nhưng guard ngay sau (`:6713-6724`) **chỉ dùng `HasChangeds` và `hasIsPrices`** ⇒ biến được tính rồi **bỏ không dùng**. SalesOrder **yếu hơn** DistributorOrder ở điểm này. Phải tự viết đúng.

Tham khảo được: SalesOrder1 **có** invalidate cờ trên đường copy/duplicate — `EditingDoc.IsPromotion = false;` tại `:2348` và `:2478`.

**KHÔNG làm trong đợt này:** mở rộng sang yêu cầu BP 4.3 (tính lại khi bảng giá/CTKM đổi — chờ Q7); bật lại `ValidateProductDetailsPriceAsync()` đang comment-out `:881-890` (chờ Q8, phải biết vì sao nó bị tắt).

**Verify:**
- Tạo đơn → thêm SP → Tính giá → Tính KM → đổi ngày đặt hàng (cả tương lai và quá khứ) → Lưu ⇒ hiện đúng message, **trạng thái đơn không đổi**.
- Tính lại giá + KM sau khi đổi ngày ⇒ Lưu thành công bình thường.
- Không đổi ngày ⇒ Lưu bình thường, **không** hiện cảnh báo (không được false positive).
- Kiểm tra **cả hai** đường: tạo mới (`SaveDataNewAsync`) và cập nhật (`SaveDataAsync`).
- Kiểm tra **cả hai** màn (`IsApproveScreen` true/false) vì dùng chung component.

---

### Báo cáo cuối

Với **mỗi** issue, báo cáo đủ:
- Số issue + branch name
- Commit hash (kèm commit trace nếu có)
- Trạng thái push (chỉ push branch issue, không push gì khác)
- Danh sách file đã đổi
- Kết quả verify từng mục ở phần Verify
- File dirty không liên quan đã giữ nguyên
- **Bất cứ thứ gì đã bỏ qua hoặc chưa chắc chắn** (Rule 12)

Cuối cùng, liệt kê rõ các issue **chưa làm** (#3, #4, #5, #6, #7, #9, #11, #13) và câu hỏi đang chờ user chốt (Q1, Q3, Q4, Q5, Q6, Q7, Q8) — xem phụ lục cuối `01-issue-analysis.md`.

## HẾT PROMPT

---

## Ghi chú cho người bàn giao (không gửi cho Codex)

**Session phân tích:** `d31e4e15-3c70-4124-92b6-870cee2542a4`
Resume bằng: `claude --resume d31e4e15-3c70-4124-92b6-870cee2542a4`

**Câu hỏi cần chốt để mở khoá 9 issue còn lại:**

| Câu | Issue bị chặn | Nội dung |
|---|---|---|
| Q1 | #7 | Popup chọn nhiều item code áp dụng màn nào? BP 4.2 / BP 4.3 / tracker mâu thuẫn |
| Q2 | #7 | Mở popup có tự điền SL vào item code version mới nhất không? |
| Q3 | #4, #6 | Xem trước dùng chung report DC hay report riêng cho đơn NPP? |
| Q4 | #13 | Thu hồi `.Edit` khỏi NPP (cấu hình) hay thêm quyền `Approve` riêng (sửa code)? |
| Q5 | #3 | Có sửa lệch cấu trúc quyền UI↔Server đợt này không? |
| Q6 | #8 | `customerCode` cố định ô C3 là đúng thiết kế hay bug? |
| Q7 | #12 | Có mở rộng sang tính lại khi bảng giá/CTKM đổi không? |
| Q8 | #12 | `ValidateProductDetailsPriceAsync()` bị comment-out vì sao? |
| Q9 | chung | Gap G1–G8 (mục 6 của `00-blueprint-analysis.md`) có vào đợt này không? |

Sau khi có câu trả lời, quay lại session Opus để cập nhật phân tích và sinh prompt đợt 2.
