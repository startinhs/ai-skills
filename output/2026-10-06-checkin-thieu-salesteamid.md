# Fix: check-in/check-out bị lưu thiếu SalesTeamId, app báo "Error"

Ngày lập: 06/10/2026. Cập nhật: 07/10/2026 (thêm ca check-out). Trạng thái: chưa sửa.

## Tóm tắt

App mobile có lúc gửi check-in và check-out với `salesTeamId` rỗng. Server vẫn lưu, với `SalesTeamId = NULL`. Hậu quả:

- Check-in thiếu team: danh sách vẫn hiện "Chưa viếng thăm", bấm lại thì server chặn (403) và app hiện "Error".
- Check-out thiếu team: không đóng được phiên trong danh sách khách hàng, khách bị gắn nhãn sai "NV khác đang Check-in".
- Check-out một phiên thiếu team: app gửi `salesID` rỗng, server trả 400, app hiện "Check-out thất bại".

Cần làm 7 việc, xếp theo thứ tự ưu tiên:

| # | Nơi sửa | Việc | Tác dụng |
|---|---|---|---|
| 1 | App | Lưu `saleTeamId` vào cache user info, chặn gửi khi team rỗng | Sửa gốc: team không còn bị rỗng |
| 2 | Backend | Tự điền team khi request thiếu `SalesTeamId` | Chặn dữ liệu sai, kể cả với bản app cũ |
| 2b | Backend | Check-out/đóng cửa lấy team từ lượt IO mà nó đóng | Check-out luôn đóng được phiên |
| 3 | App | Hiện thông báo lỗi của server | Nhân viên biết lý do thay vì thấy "Error" |
| 4 | DB | Dọn các lượt IO/OO có team NULL | Sửa số liệu viếng thăm đã sai |
| 5 | App + Backend | Nhãn "NV khác đang Check-in" xét đúng chủ phiên | Không gắn nhãn sai cho phiên của chính user |
| 6 | App | Ghi log lúc khôi phục phiên, chọn đội, gửi request thiếu team | Biết chính xác team mất lúc nào |

Mục 2 và 2b nên phát hành trước vì không phụ thuộc việc nhân viên cập nhật app.

## Hiện tượng và phạm vi

- Nhân viên bấm "Viếng thăm", app báo "Error", không vào được màn hình viếng thăm. Danh sách khách hàng vẫn hiện "Chưa viếng thăm".
- Ba ca đã làm nhân viên dừng bán hàng:
  - nam_nx, 05/10 16:07–16:19, khách 1420334536.
  - nguyen_vd, 06/10 từ 11:26, khách 1429035819.
  - ĐỖ MẠNH TUẤN (20080720002), 07/10 12:21–12:58, khách 1420329108 (TẠP HÓA 247). Xem diễn biến ở mục "Ca check-out".
- Từ 01/09 đến 06/10 có khoảng 140 lượt IO với `SalesTeamId = NULL`, trên khoảng 70 nhân viên. Từ 21/09 ngày làm việc nào cũng có.

## Nguyên nhân

### Vì sao team bị rỗng

1. Body check-in lấy team từ biến trong bộ nhớ: `GeneralApp.userInfo?.saleTeamId ?? ''`.
2. Khi lưu user info xuống máy, `_$UserInfoToJson` không ghi `saleTeamId` và `saleTeamDescription`. Khi đọc lại, `fromJson` gán `saleTeamId = ''`.
3. App nạp user info từ cache ở hai chỗ:
   - Mở lại app (auto-login): `lib/core/authentication/authentication_bloc.dart`, nhánh `event.isRestore`.
   - Mở hộp "Chọn đội bán hàng": `lib/views/screens/main_menu/bloc_main_menu/main_menu_bloc.dart`, hàm `_mapFetchSalesTeamList`.
4. Team chỉ có lại khi nhân viên bấm "Xác nhận" đội và cả `setUsingSalesTeam` lẫn `fetchUserInfo` thành công. Nếu mạng yếu hoặc server chậm, bước này lỗi và team vẫn rỗng. Nhân viên vẫn vào danh sách khách hàng và check-in được.
5. Hộp chọn đội chỉ tự bật **một lần**, khi màn hình chính khởi tạo (`main_menu_form.dart`, `initState` gọi `checkConnect()` rồi `onConnectedNetwork`). Khi mạng thay đổi, `NetworkBaseMixin` chỉ gọi `onNetworkChanged`, mà màn hình chính không override hàm này. Vì vậy nếu lần chọn đội đầu tiên lỗi, app **không tự thử lại**; team rỗng đến khi nhân viên tự vào menu chọn đội hoặc đăng nhập lại.

### Vì sao server chặn lần bấm sau

- Lượt IO đầu được lưu với team NULL.
- Danh sách khách hàng tìm phiên đang mở theo team, nên không thấy lượt này và vẫn hiện "Chưa viếng thăm".
- Khi bấm lại, server so `SalesTeamId` của request (NULL) với trace cũ (NULL), thấy khớp, và trả 403 "Đã check-in trong ngày này rồi, vui lòng check-out".

### Vì sao app hiện "Error"

`checkInOut` trong `lib/data/remote/sfa_customer_api_client.dart` chỉ trả `true/false` theo mã HTTP và bỏ nội dung phản hồi.

### Ca check-out (ĐỖ MẠNH TUẤN, 07/10)

| Giờ | Sự kiện | Team |
|---|---|---|
| 08:21 → 11:52 | 17 khách bình thường | có |
| 11:56:37 | IO TẠP HÓA 247 | có |
| 12:21:21 | OO TẠP HÓA 247 | NULL |
| 12:22:03 | IO SIÊU TIỆN ÍCH (1429010575), không có OO | NULL |
| 12:23:58 | IO lại TẠP HÓA 247 | NULL |
| 12:29:09 | Check-out lỗi 400, app hiện "Check-out thất bại" | |
| 12:33:23 | CL + OO TẠP HÓA 247 | NULL |
| 12:36:42 | IO NGUYỄN THỊ VIỆT (1429020793), không có OO | NULL |
| 12:58:28 | IO lại NGUYỄN THỊ VIỆT, CL + OO bình thường | có |

App mất team trong khoảng 11:56–12:21, khi nhân viên đang ở TẠP HÓA 247. Chưa xác định được lý do cụ thể.

#### Vì sao check-out thiếu team không đóng được phiên

- Server nhận OO thiếu team: `ResolveOpenIOTraceAsync` gặp `salesTeamId` NULL thì bỏ lọc team, vẫn tìm thấy IO 11:56 và ghi OO, nhưng OO mang `SalesTeamId` của request (NULL).
- Danh sách khách hàng (`SFAVisitInCallHelper.GetTeamInCallSessionsAsync`) chỉ tính OO có `SalesTeamId` bằng team đang xem. OO NULL không được tính, nên IO 11:56 vẫn bị coi là đang mở.

#### Vì sao nhãn "NV khác đang Check-in" sai

`_mapVisitStatus` trong `lib/views/screens/customer_list/bloc_customer_list/customer_list_form.dart` gắn nhãn này khi `isCheckin == true` và khách khác `custIdIncall`. App không biết phiên đó của ai, nên phiên của chính nhân viên ở một khách khác cũng bị gắn "NV khác".

#### Vì sao "Check-out thất bại" (400)

- Khi check-out, app lấy `salesID` từ API thông tin khách hàng (`customer_detail_form.dart`, `_customerModel?.salesID = _customerDetail?.salesID ?? ''`).
- `FetchCustomerInfo` chỉ tìm phiên đang mở khi có `salesTeamId` và chỉ theo team (`SFAVisitInCallHelper.ResolveCustomerInCallAsync`). App đang rỗng team, hoặc IO 12:23:58 thiếu team, nên không tìm thấy và `salesID` rỗng.
- Server không parse được `"salesID": ""` thành `Guid`, trả 400: `The JSON value could not be converted to System.Guid. Path: $.salesID`.
- "Đóng cửa" lúc 12:33 qua được vì không cần `salesID` để tìm phiên.

## Cách sửa

### 1. App: lưu `saleTeamId` vào cache

File: `lib/data/model_map_json/user_infor_model.g.dart`, hàm `_$UserInfoToJson`. Thêm hai dòng:

```dart
'saleTeamId': instance.saleTeamId,
'saleTeamDescription': instance.saleTeamDescription,
```

File này có dòng "GENERATED CODE" nhưng đang được sửa tay (ví dụ key `id` thay cho `userID`), nên sửa trực tiếp. Không chạy lại `build_runner` cho file này vì sẽ mất các chỉnh sửa tay.

Cache cũ trên máy nhân viên không có `saleTeamId`. Vì vậy cần thêm một bước dự phòng: khi nạp user info từ cache mà `saleTeamId` rỗng, gọi `fetchUserInfo()` để lấy lại từ server rồi lưu lại cache. Đặt ở cả hai chỗ nạp cache nêu trên.

### 1b. App: chặn check-in khi team rỗng

Có 7 chỗ dựng `VisitRequestModel` với `salesTeamId: GeneralApp.userInfo?.saleTeamId ?? ''`:

- `bloc_check_in_out/check_in_out_bloc.dart` (1 chỗ, hàm `generatedBodyCheckInOut`)
- `bloc_customer_list/customer_list_bloc.dart` (3 chỗ)
- `bloc_customer_detail/customer_detail_bloc.dart` (3 chỗ)

Ngoài ra, khi bước chọn đội lần đầu lỗi (`SalesTeamListErrorState` hoặc `SalesTeamConfirmErrorState` với `isInitialFlow`), app nên cho thử lại: hiện hộp thông báo có nút "Thử lại", hoặc gọi lại `FetchSalesTeamListEvent` khi mạng có lại (override `onNetworkChanged` ở màn hình chính).

Cách gọn nhất là chặn ở một điểm chung, `SfaCustomerRepository.checkInOut` trong `lib/data/repository/sfa_customer_repository.dart`: nếu `body.salesTeamId` rỗng thì thử `fetchUserInfo()` một lần; nếu vẫn rỗng thì ném lỗi có thông báo "Chưa xác định được đội bán hàng, vui lòng chọn lại đội". Điểm chặn này áp dụng cho mọi loại (IO, OO, CL, NV), không chỉ check-in.

Cùng chỗ đó, với OO: nếu `body.salesID` rỗng thì gọi lại API thông tin khách hàng để lấy `salesID`; nếu vẫn rỗng thì báo "Không tìm thấy phiên check-in để check-out, vui lòng tải lại danh sách" thay vì gửi request sẽ bị 400.

### 2. Backend: tự điền team khi request thiếu

File: `backendavn/modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.EntityFrameworkCore/SFAOutsideCheckings/EfCoreSFAOutsideCheckingRepository.Extended.cs`, hàm `HandleAsync`.

Thêm ngay sau khi lấy `slsperID`, trước nhánh `UnvisitAll`:

```csharp
if (!request.SalesTeamId.HasValue || request.SalesTeamId == Guid.Empty)
{
    request.SalesTeamId = await _sfaCommonAppService.GetUsingSalesTeamIdAsync();
}
```

- `_sfaCommonAppService` đã được inject sẵn trong repository này.
- `GetUsingSalesTeamIdAsync` trả team đang dùng của user, và ném `UserFriendlyException` nếu user không có đội nào.
- Sau khi sửa, bước kiểm tra "nhân viên khác đang check-in" luôn chạy, vì nó phụ thuộc `SalesTeamId.HasValue`.

Cần kiểm tra thêm luồng đồng bộ offline (`SfaSyncAppService.PushCheckIns.cs`) vì DTO ở đó cũng có `Guid? SalesTeamId`. Chưa xác minh luồng này có gọi chung `HandleAsync` hay không.

### 2b. Backend: check-out lấy team từ lượt IO mà nó đóng

Cùng file và hàm. Với OO và CL, sau khi tìm được IO đang mở (`latestOpenIOTraceForThisSales` / `latestOpenIOTraceForCL`), ghi trace OO/CL với `SalesTeamId` của chính IO đó thay vì của request. Nếu IO cũng thiếu team thì mới dùng team của request.

Lý do: nếu nhân viên đổi đội giữa lúc check-in và check-out, hoặc request thiếu team, OO vẫn khớp team với IO nên danh sách khách hàng thấy phiên đã đóng. Chưa đọc đoạn code ghi trace OO/CL; cần xác định chỗ gán `SalesTeamId` khi thực hiện.

### 3. App: hiện thông báo lỗi của server

File: `lib/data/remote/sfa_customer_api_client.dart`, hàm `checkInOut`.

Khi mã trả về không phải 200/204, đọc `error.message` trong body và ném lỗi mang thông báo đó, thay vì trả `false`. Body lỗi của server có dạng:

```json
{ "error": { "code": null, "message": "Đã check-in trong ngày này rồi, vui lòng check-out" } }
```

Ba bloc gọi `checkInOut` đều đã có `catch` và phát state lỗi kèm `message`. Hai trong số đó gắn tiền tố sai "Lỗi tải danh sách khách hàng:" (ở `customer_list_bloc.dart` và `customer_detail_bloc.dart`); nên bỏ tiền tố này cho nhánh check-in.

### 4. Dọn dữ liệu

Liệt kê các lượt cần xử lý:

```sql
SELECT t."Id", t."TraceTime", t."Type", eu."UserName", eu."EmployeeName",
       cu."Code" AS cust_code, t."SalesID", t."SFAOutsideCheckingId",
       eu."SalesTeamsId" AS team_hien_tai_cua_user
FROM "SFASalesTraces" t
LEFT JOIN "ExtendedUsers" eu ON eu."Id" = t."ExtendedUserId"
LEFT JOIN "Customers" cu     ON cu."Id" = t."CustomerId"
WHERE t."SalesTeamId" IS NULL
  AND t."IsDeleted" = false
  AND t."TraceTime" >= DATE '2026-09-01'
ORDER BY t."TraceTime";
```

Cách xử lý từng dòng cần thống nhất với nghiệp vụ trước khi chạy, vì có hai lựa chọn:

- Gán lại team (theo team của user tại thời điểm đó) và bổ sung OO để đóng phiên.
- Đánh dấu xóa mềm các IO mồ côi mà nhân viên đã check-in lại thành công sau đó (như ca nam_nx lúc 16:19).

Bảng `SFAOutsideCheckings` cũng có thể có dòng team NULL tương ứng; cần kiểm tra cùng lúc.

Query trên lấy cả OO/CL có team NULL. Riêng OO NULL đóng một IO có team (như OO 12:21 của ĐỖ MẠNH TUẤN), cách xử lý đơn giản nhất là gán cho OO team của IO cùng `SalesID`:

```sql
-- Xem trước, chưa cập nhật
SELECT oo."Id", oo."TraceTime", oo."SalesID", io."SalesTeamId" AS team_cua_io
FROM "SFASalesTraces" oo
JOIN "SFASalesTraces" io ON io."SalesID" = oo."SalesID"
                        AND io."Type" = 'IO'
                        AND io."SalesTeamId" IS NOT NULL
                        AND io."IsDeleted" = false
WHERE oo."Type" IN ('OO', 'CL')
  AND oo."SalesTeamId" IS NULL
  AND oo."IsDeleted" = false;
```

### 5. App + Backend: nhãn "NV khác đang Check-in"

Hiện app suy ra "NV khác" chỉ bằng cách so khách với `custIdIncall`. Đề xuất:

- Backend `FetchSalesRoute`: trả thêm cho mỗi khách đang có phiên mở người đang giữ phiên (ví dụ `inCallExtendedUserId`, đã có sẵn trong `InCallSessionRow.ExtendedUserId`).
- App `_mapVisitStatus`: chỉ gắn "NV khác đang Check-in" khi người giữ phiên khác user hiện tại. Nếu là chính user ở khách khác, hiện trạng thái riêng (ví dụ "Bạn chưa check-out khách này") để nhân viên biết mà xử lý.

### 6. App: ghi log để xác định lúc mất team

Log server không ghi user, và log cục bộ của app (`PPC_Log`) được gửi lên endpoint `LogV4/SaveLogV4` mà không thấy trong backend, nên hiện không có cách biết team mất lúc nào.

Dùng kênh đang hoạt động `AppClientLogApiClient().logException(...)` (server ghi ra dòng `[AppClientException]`, đang được máy in dùng). Gửi kèm username và giờ trong `message`, ví dụ `source: 'SalesTeam'`. Ghi ở 4 chỗ:

| Chỗ | Nội dung log |
|---|---|
| `authentication_bloc.dart`, nhánh `isRestore` | App khôi phục phiên; team đọc từ cache (rỗng hay không) |
| `main_menu_bloc.dart`, `_mapFetchSalesTeamList` | Đã ghi đè user info từ cache; team sau khi ghi đè |
| `main_menu_bloc.dart`, hai nhánh lỗi tải/xác nhận đội | Bước nào lỗi, nội dung lỗi |
| `SfaCustomerRepository.checkInOut` | Request IO/OO/CL/NV bị chặn vì team hoặc `salesID` rỗng |

Kênh này không xác thực và chỉ ghi ra log, không lưu DB; không gửi dữ liệu nhạy cảm ngoài username.

## Cách kiểm thử

1. Đăng nhập, chọn đội, check-in một khách: trace có `SalesTeamId`.
2. Tắt hẳn app rồi mở lại (auto-login), bật chế độ máy bay trước khi hộp chọn đội tải xong, sau đó bật mạng lại và check-in: trace phải có `SalesTeamId`. Đây là kịch bản tái hiện lỗi.
3. Dùng bản app cũ (chưa sửa) gọi vào backend mới với `salesTeamId` rỗng: trace vẫn có `SalesTeamId`.
4. Hai nhân viên cùng đội check-in cùng một khách: người thứ hai thấy đúng câu "Nhân viên khác đang check-in tại khách hàng này", không phải "Error".
5. Check-in một khách, xóa team trong bộ nhớ app (giả lập), rồi check-out: OO phải mang team của IO, và khách hiện "Đã viếng thăm" sau khi tải lại.
6. Check-out khi app không lấy được `salesID`: app hiện thông báo rõ, không gửi request lên server.
7. Nhân viên A check-in khách X, chưa check-out, rồi mở khách Y: khách X không được gắn "NV khác đang Check-in".
8. Sau khi phát hành, chạy lại query đếm IO và OO có team NULL theo ngày: số phát sinh mới phải bằng 0.

## Điểm chưa chắc chắn

- Việc nhân viên "mở lại app và bước xác nhận đội bị lỗi" là suy luận từ code và mốc thời gian. Log server không ghi user nên chưa có bằng chứng trực tiếp. Phần team NULL thì DB đã xác nhận.
- Ca 07/10: log server 11:56–12:21 cho thấy mọi request chọn đội tới server đều thành công và nhanh (`getListSalesTeam` 15, `getUsingSalesTeam` 15, `setUsingSalesTeam` 16, `fetchUserInfor` 18, đều 200, dưới 5 giây). Nếu bước chọn đội của nhân viên này có lỗi thì lỗi xảy ra trên máy hoặc đường truyền, request không tới server. Cùng khoảng đó có 2 request check-in chạy 60 giây (11:59:33 trả 500, 12:02:09 trả 499). Chưa chốt được nguyên nhân mất team; cần log ở mục 6.
- Chưa rõ vì sao số ca tăng từ 21/09 (có thể do phát hành bản app mới hoặc mở rộng số người dùng).
- Lỗi `ClientException: Connection closed before full header was received` ở ca nguyen_vd là rớt kết nối, không thuộc phạm vi các sửa đổi trên.
