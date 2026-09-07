# Phân tích: Lazy loading / Server-side paging khách hàng cho màn hình "NPP thuộc đội" (DistributorOfTeam)

> Phạm vi: **CHỈ PHÂN TÍCH**. Không có bất kỳ file source nào bị thay đổi.
> Codebase: `d:\PROJECTS\Xspire_AVN\backendavn` (nhánh hiện tại `test/distributor-of-team-tinhlm`, HEAD `2f89743e0`).
> Ngày phân tích: 2026-08-31.

---

## 0. Tóm tắt điều hành (TL;DR)

| Câu hỏi | Trả lời |
|---|---|
| Hiện tại load bao nhiêu khách hàng? | **Tối đa 1.000**, nạp một lần vào `CustomerCollection`, tìm kiếm hoàn toàn client-side. |
| API đã đủ để server-paging chưa? | **ĐỦ 100%.** `GetListComboboxDataPagedAsync` + `GetComboboxByIdAsync` đã có sẵn, đã được SalesOrder dùng ở production. |
| Có cần sửa backend không? | **KHÔNG.** Không cần sửa AppService, Contract, Repository, hay DTO. |
| Có cần sửa `HQSOFTComboBox` không? | **KHÔNG.** Component đã hỗ trợ đầy đủ (`LoadCustomDataAsync`, `LoadSelectedItemAsync`, virtual scroll, session cache, dedupe). |
| Phạm vi thay đổi | **2 file duy nhất**: `DistributorOfTeam.razor` + `DistributorOfTeam.razor.cs`. |
| Có ảnh hưởng fill data trên form không? | **KHÔNG**, với 3 điều kiện bắt buộc — xem [Mục 16](#16-kết-luận-về-ảnh-hưởng-fill-data). |
| Nguyên nhân lỗi "chọn xong bị trắng" trước đây | Callback ghi vào biến global `EditingDistributorOfTeamDetail` thay vì `context.EditModel` của dòng. Commit `df7ccac29` đã sửa đúng hướng nhưng **còn sót 1 dòng** `EditingDistributorOfTeamDetail = editModel;` gây tái nhiễm — xem [Mục 12](#12-race-condition--render-loop). |

---

## 1. Mô tả chính xác cách load khách hàng hiện tại

### 1.1. Nguồn dữ liệu: `CustomerCollection`

**File:** [DistributorOfTeam.razor.cs:78](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L78)

```csharp
private List<CustomerComboboxItemDto> CustomerCollection { get; set; } = new List<CustomerComboboxItemDto>();
```

**Nạp tại:** [DistributorOfTeam.razor.cs:751-755](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L751-L755)

```csharp
private async Task GetCollectionAsync()
{
    SalesTeamCollection = (await SalesTeamAppService.GetListDataAsNoTrackingAsync(new GetSalesTeamInput { MaxResultCount = 1000 })).OrderBy(p => p.Code).ToList();
    CustomerCollection = (await CustomersAppService.GetListComboboxDataAsync(new GetComboboxDataInput { MaxResultCount = 1000 })).OrderBy(p => p.Code).ToList();
}
```

Đặc điểm:
- Gọi **một lần** khi khởi tạo trang, nạp **toàn bộ 1.000 bản ghi đầu tiên** vào RAM của circuit Blazor Server.
- `GetListComboboxDataAsync` → `ComboboxDataLimits.ApplyMinimumPaging(input)` → **KHÔNG cap trên** (`ApplyMinimumPaging` chỉ enforce tối thiểu `MinCustomDataTake = 100`, không giới hạn max) → server thực sự trả về đủ 1.000 dòng.
- Repository ([EfCoreCustomerRepository.cs:301-320](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.cs#L301-L320)) lọc sẵn `Status IN ('a','active','hoạt động')` và sort theo `CustomerConsts.GetDefaultSorting(false)`. Trang sau đó `.OrderBy(p => p.Code)` lại lần nữa ở client.

### 1.2. Combobox "MÃ KHÁCH HÀNG"

**File:** [DistributorOfTeam.razor:226-245](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L226-L245)

```razor
<DxComboBox Data="@CustomerCollection"
            Value="@editModel.CustomerId"
            ValueExpression="@(() => editModel.CustomerId)"
            ValueChanged="@((Guid? newValue) => Grid_SelectCustomer(newValue))"
            ValueFieldName="Id"
            TextFieldName="Description"
            ...
            ListRenderMode="ListRenderMode.Virtual"
            SearchMode="ListSearchMode.AutoSearch"
            SearchTextParseMode="ListSearchTextParseMode.GroupWordsByAnd"
            SearchFilterCondition="ListSearchFilterCondition.Contains"
            ClearButtonDisplayMode="DataEditorClearButtonDisplayMode.Auto">
```

Ba vấn đề cụ thể:

1. **`Data="@CustomerCollection"` là danh sách tĩnh in-memory.** `ListRenderMode.Virtual` ở đây **chỉ ảo hoá render DOM**, không hề gọi server. `SearchFilterCondition.Contains` chạy LINQ trên đúng 1.000 phần tử đó. → Khách hàng thứ 1.001 trở đi **không thể tìm thấy bằng bất kỳ cách nào** trên UI.

2. **`TextFieldName="Description"` nhưng caption cột là "MÃ KHÁCH HÀNG".** Ô đóng hiển thị **tên** khách hàng trong cột đáng lẽ hiển thị **mã**. Đây là một bug hiển thị độc lập, đang tồn tại. So sánh: SalesOrder dùng `TextFieldName="@nameof(CustomerComboboxItemDto.Code)"`.

3. **`ValueChanged` không truyền `editModel`** → xem mục 1.3.

### 1.3. Callback chọn khách: `Grid_SelectCustomer`

**File:** [DistributorOfTeam.razor.cs:899-917](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L899-L917)

```csharp
private async Task Grid_SelectCustomer(Guid? guid)
{
    try
    {
        if (guid != null)
        {
            EditingDistributorOfTeamDetail.CustomerId = guid;          // ⚠️ GLOBAL, không phải context.EditModel
            var data = CustomerCollection.FirstOrDefault(p => p.Id == guid);
            EditingDistributorOfTeamDetail.CustomerCode = data.Code;   // ⚠️ NullReferenceException nếu ngoài 1.000
        }
    }
    catch { }                                                          // ⚠️ Nuốt lỗi im lặng
    UpdateCustomerNumber();
    await MarkAsChanged(true);
    await SafeStateHasChangedAsync();
}
```

Ba khiếm khuyết:
- Ghi vào biến **global** `EditingDistributorOfTeamDetail`, không phải `editModel` của dòng đang sửa. Hiện tại "may mắn" hoạt động vì `OnFocusedRowChanged` ([dòng 953-961](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L953-L961)) và các `CellEditTemplate` ([dòng 265, 350](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L265)) liên tục gán lại biến này = `context.EditModel`. Đây là **coupling ngầm cực kỳ mong manh** — chính là mầm mống của lỗi "chọn xong bị trắng".
- `data.Code` **không null-check** → nếu id nằm ngoài 1.000 bản ghi (ví dụ mở chứng từ cũ) → `NullReferenceException` → bị `catch {}` nuốt → `CustomerCode` **giữ nguyên giá trị của dòng trước**, dữ liệu sai lệch âm thầm.
- Không có nhánh `else` để clear khi `guid == null` → **xóa khách hàng không clear được `CustomerCode`**.

### 1.4. Cột hiển thị (đã KHÔNG phụ thuộc CustomerCollection)

Điểm quan trọng thường bị bỏ sót: **`CellDisplayTemplate` đã dùng `HQSOFTCellDisplayTemplate` — tức là đã lazy-load từ server rồi.**

| Vị trí | Template | Nguồn dữ liệu |
|---|---|---|
| [razor:193-205](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L193-L205) — cột MÃ, `CellDisplayTemplate` | `HQSOFTCellDisplayTemplate TItem="CustomerDto" DisplayField="Code"` | `DataQueryHelper` (server + cache) ✅ |
| [razor:250-261](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L250-L261) — cột TÊN, `CellDisplayTemplate` | `HQSOFTCellDisplayTemplate TItem="CustomerDto" DisplayField="CustomerName"` | `DataQueryHelper` (server + cache) ✅ |
| [razor:263-280](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L263-L280) — cột TÊN, `CellEditTemplate` | `CustomerCollection.FirstOrDefault(...)` | **In-memory 1.000** ❌ |

→ Trong toàn bộ trang, `CustomerCollection` chỉ còn được dùng đúng **2 chỗ**: `Data=` của DxComboBox và `CellEditTemplate` của cột TÊN. Cả hai đều thay được. **Không có chỗ nào khác cần `CustomerCollection`.**

### 1.5. Hệ quả nghiệp vụ

- Khách hàng thứ 1.001+ không tồn tại trên UI dù có trong DB.
- Nếu tổng số KH hoạt động > 1.000: 1.000 dòng đó là 1.000 dòng **đầu theo sort mặc định** — người dùng không có cách nào biết mình đang thiếu ai.
- Mở chứng từ cũ có `CustomerId` nằm ngoài 1.000: cột hiển thị **vẫn đúng** (nhờ `HQSOFTCellDisplayTemplate`), nhưng khi vào chế độ sửa ô thì combobox **trống** và ô TÊN trong `CellEditTemplate` cũng **trống**.
- Memory: mỗi circuit Blazor Server giữ 1.000 DTO. Với N người dùng đồng thời → N × 1.000 objects.

---

## 2. So sánh với cách SalesOrder lazy load khách hàng

### 2.1. Markup SalesOrder

**File:** [SalesOrder.razor:355-379](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor#L355-L379)

```razor
<HQSOFTComboBox TData="CustomerComboboxItemDto" TValue="Guid"
                Value="@EditingDoc.CustomerXSId"
                ValueExpression="@(() => EditingDoc.CustomerXSId)"
                ValueChanged="@(async (Guid newValue) => { await SelectedCustomer(newValue);})"
                TextFieldName="@nameof(CustomerComboboxItemDto.Code)"
                ValueFieldName="Id"
                EditFormat="{0}"
                DisplayFormat="{0}"
                id="@($"ne_Cbx_{nameof(EditingDoc.CustomerXSId)}")"
                Enabled="@(CanEdit && !IsReadOnly && EditingDocId == Guid.Empty)"
                LoadSelectedItemAsync="@LoadCustomerSelectedFromSourceAsync"
                LoadCustomDataAsync="@LoadCustomerCustomDataAsync"
                ShowValidationIcon="true"
                ValidationEnabled="true">
    <Columns>
        <DxListEditorColumn FieldName="@nameof(CustomerComboboxItemDto.Code)" Caption="@L["Code"]" />
        <DxListEditorColumn FieldName="@nameof(CustomerComboboxItemDto.Description)" Caption="@L["Description"]" />
    </Columns>
</HQSOFTComboBox>
```

### 2.2. Code-behind SalesOrder

**File:** [SalesOrder.razor.cs:12825-12865](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs#L12825-L12865)

```csharp
private async Task<LoadResult> BuildPagedCustomDataAsync<TItem>(
    DataSourceLoadOptionsBase options,
    CancellationToken cancellationToken,
    Func<GetComboboxDataInput, Task<PagedResultDto<TItem>>> loadAsync)
{
    cancellationToken.ThrowIfCancellationRequested();
    var input = ComboboxCustomDataHelper.ToComboboxInput(options);
    var dataInput = new GetComboboxDataInput
    {
        FilterText     = input.FilterText,
        SkipCount      = input.SkipCount,
        MaxResultCount = input.MaxResultCount
    };

    var page = await loadAsync(dataInput);
    cancellationToken.ThrowIfCancellationRequested();

    return new LoadResult
    {
        data       = page.Items?.ToList() ?? new List<TItem>(),
        totalCount = (int)page.TotalCount
    };
}

// Customer (large dataset — server-side paging)
private Task<LoadResult> LoadCustomerCustomDataAsync(DataSourceLoadOptionsBase options, CancellationToken ct)
    => BuildPagedCustomDataAsync(options, ct,
        x => CustomerAppService.GetListComboboxDataPagedAsync(x));

private async Task<List<CustomerComboboxItemDto>> LoadCustomerSelectedFromSourceAsync(Guid v)
{
    if (v == Guid.Empty) return new List<CustomerComboboxItemDto>();
    try
    {
        var dto = await GetCustomerComboboxByIdCachedAsync(v);
        return dto == null ? new List<CustomerComboboxItemDto>() : new List<CustomerComboboxItemDto> { dto };
    }
    catch
    {
        return new List<CustomerComboboxItemDto>();
    }
}
```

### 2.3. Bảng so sánh

| Tiêu chí | DistributorOfTeam (hiện tại) | SalesOrder (chuẩn) |
|---|---|---|
| Component | `DxComboBox` thuần | `HQSOFTComboBox` |
| Nguồn dữ liệu | `Data="@CustomerCollection"` (List tĩnh) | `LoadCustomDataAsync` (callback server) |
| API paging | `GetListComboboxDataAsync` (1 lần, 1.000) | `GetListComboboxDataPagedAsync` (mỗi chunk) |
| Phạm vi tìm kiếm | 1.000 dòng client-side | **Toàn bộ DB** server-side (`ApplyUnaccentFilter`) |
| Bỏ dấu tiếng Việt | LINQ `Contains` (phân biệt dấu) | `ApplyUnaccentFilter` (bỏ dấu, đúng nghiệp vụ VN) |
| Fill khi mở doc cũ | Tìm trong list → hỏng nếu ngoài 1.000 | `LoadSelectedItemAsync` → `GetComboboxByIdAsync` ✅ |
| TextFieldName | `Description` (sai với caption "MÃ") | `Code` ✅ |
| DataLoadMode | (mặc định) | `OnDemand` |
| Bộ nhớ / circuit | 1.000 DTO thường trú | ~100–200 DTO/chunk, giải phóng khi đóng dropdown |
| Debounce / dedupe / hủy request | Không | Có (session cache, coalesce, CTS) |
| Quick-resolve (paste mã + Tab) | Không | Có (tự động bật khi có `LoadCustomDataAsync`) |

### 2.4. Điểm khác biệt kiến trúc quan trọng cần lưu ý

SalesOrder bind vào **`EditingDoc` — một object header duy nhất**. DistributorOfTeam bind vào **`context.EditModel` — một object khác nhau cho mỗi dòng grid**. Đây chính là toàn bộ độ khó của việc port pattern này sang grid, và cũng là nguyên nhân gốc của lỗi "chọn xong bị trắng" trước đây. **Không thể copy-paste nguyên xi SalesOrder** — bắt buộc phải truyền `editModel` qua callback.

Codebase đã có sẵn **một tiền lệ in-grid hoạt động đúng**: [SalesRoute.razor:322-355](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L322-L355). Đây mới là mẫu chuẩn để copy, không phải SalesOrder.

---

## 3. Xác nhận API hiện tại có đủ để server paging không

### ✅ ĐỦ HOÀN TOÀN. Không cần sửa một dòng backend nào.

### 3.1. `GetListComboboxDataPagedAsync` — phân trang + tìm kiếm

**Contract:** [ICustomersAppService.cs:24](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/Customers/ICustomersAppService.cs#L24)
```csharp
Task<PagedResultDto<CustomerComboboxItemDto>> GetListComboboxDataPagedAsync(GetComboboxDataInput input);
```

**Impl:** [CustomersAppService.cs:321-348](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/Customers/CustomersAppService.cs#L321-L348)
```csharp
public virtual async Task<PagedResultDto<CustomerComboboxItemDto>> GetListComboboxDataPagedAsync(GetComboboxDataInput input)
{
    ComboboxDataLimits.ApplyNormalizedPaging(input);                                    // ✅ chuẩn hoá skip/take
    var totalCount = await _customerRepository.GetCountComboboxDataAsync(input.FilterText, CancellationToken.None);  // ✅ tổng thật
    var items = await _customerRepository.GetListComboboxDataAsync(
        input.FilterText, null, null, input.Status, input.Sorting,
        input.MaxResultCount, input.SkipCount, CancellationToken.None);                  // ✅ Skip/Take xuống DB
    ...
    return new PagedResultDto<CustomerComboboxItemDto>(totalCount, results);
}
```

Ba yếu tố quan trọng đã đủ:

**(a) Skip/Take chạm tới DB thật:** [EfCoreCustomerRepository.cs:301-322](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.cs#L301-L322)
```csharp
var items = await query.Skip(skipCount).Take(maxResultCount)   // ✅ SQL OFFSET/FETCH
    .GroupJoin(...)
```

**(b) FilterText lọc toàn bộ DB, bỏ dấu tiếng Việt:**
```csharp
query = query.ApplyUnaccentFilter(filterText, e => e.Code, e => e.CustomerName);
```
→ Tìm "sai gon" ra "SÀI GÒN". Đây là thứ client-side `Contains` **không làm được**.

**(c) `TotalCount` chính xác, filter khớp hoàn toàn với query lấy dữ liệu:**
[EfCoreCustomerRepository.Extended.cs:1171-1182](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.Extended.cs#L1171-L1182)
```csharp
public virtual async Task<long> GetCountComboboxDataAsync(string? filterText = null, CancellationToken ct = default)
{
    var query = (await GetQueryableAsync()).AsNoTracking().Where(s =>
        s.Status != null && (s.Status.ToLower() == "a" || s.Status.ToLower() == "active" || s.Status.ToLower() == "hoạt động"));
    query = query.ApplyUnaccentFilter(filterText, e => e.Code, e => e.CustomerName);
    return await query.LongCountAsync(ct);
}
```
> **Kiểm chứng khớp filter:** cả hai method dùng **cùng** điều kiện Status và **cùng** `ApplyUnaccentFilter(filterText, e => e.Code, e => e.CustomerName)`. Do đó `totalCount` khớp chính xác với tập được phân trang → **virtual scroll của DevExpress sẽ tính đúng chiều cao scrollbar và không bị treo/nhảy**. Đây là điều kiện then chốt mà nhiều API paging làm sai.

### 3.2. `GetComboboxByIdAsync` — resolve 1 bản ghi theo Id

**Impl:** [CustomersAppService.cs:350-369](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/Customers/CustomersAppService.cs#L350-L369)
```csharp
public virtual async Task<CustomerComboboxItemDto?> GetComboboxByIdAsync(Guid id)
{
    var entity = (await _customerRepository.GetListComboboxDataByDocIdsAsync(new List<Guid> { id }, CancellationToken.None)).FirstOrDefault();
    if (entity.Id == Guid.Empty) return null;
    return new CustomerComboboxItemDto { Id = entity.Id, Code = entity.Code, Description = entity.Description, ... };
}
```

> **Điểm cực kỳ quan trọng cho việc mở chứng từ cũ:**
> `GetListComboboxDataByDocIdsAsync` ([Extended.cs:1184-1197](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.Extended.cs#L1184-L1197)) chỉ filter `idSet.Contains(c.Id)` — **KHÔNG có điều kiện Status**.
> → Khách hàng đã bị **ngưng hoạt động** vẫn resolve được tên/mã.
> → Mở chứng từ cũ tham chiếu KH inactive: **vẫn hiển thị đúng, không mất dữ liệu**. Đây chính xác là hành vi ta cần.
> → Ngược lại, họ **không xuất hiện trong dropdown** (vì `GetListComboboxDataAsync` lọc Status) — đúng nghiệp vụ: không cho chọn mới KH đã ngưng, nhưng không phá dữ liệu cũ.

### 3.3. `GetListComboboxDataAsync` — vì sao KHÔNG nên tiếp tục dùng

[CustomersAppService.cs:314-319](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/Customers/CustomersAppService.cs#L314-L319) — dùng `ApplyMinimumPaging` (không cap trên) và trả `List<T>` **không có TotalCount** → không thể dùng cho virtual scroll. Đây là API "load-all", đúng cho danh mục nhỏ (< vài trăm dòng), **sai** cho Customer.

### 3.4. Tham số phân trang đã được đồng bộ 2 đầu

**Client:** [ComboboxCustomDataHelper.cs:19-38](src/HQSOFT.Xspire.Application.Blazor/Commons/Helper/LazyCombobox/ComboboxCustomDataHelper.cs#L19-L38)
```csharp
var skip = Math.Max(0, options.Skip);
var rawTake = options.Take > 0 ? options.Take : ComboboxDataLimits.DefaultPageSize;   // 100
var take = Math.Min(ComboboxDataLimits.MaxPageSize,                                    // 200
                    Math.Max(rawTake, ComboboxDataLimits.MinCustomDataTake));          // 100
return new GetComboboxDataInput { SkipCount = skip, MaxResultCount = take, FilterText = TryExtractFilterSearchText(options.Filter) };
```

**Server:** `ComboboxDataLimits.ApplyNormalizedPaging` áp **đúng công thức đó lần nữa** ([ComboboxDataLimits.cs:33-45](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/Shared/ComboboxDataLimits.cs#L33-L45)) → idempotent, hai đầu không lệch.

Hằng số: `DefaultPageSize = 100`, `MaxPageSize = 200`, `MinCustomDataTake = 100`.
→ Mỗi chunk 100–200 dòng. Cuộn hết 10.000 KH = ~50–100 request nhỏ thay vì 1 request 1.000 dòng nặng.

**Kết luận Mục 3: Backend sẵn sàng 100%. Toàn bộ công việc nằm ở tầng Blazor.**

---

## 4. Đề xuất component, generic type và các property cần dùng

### 4.1. Component: `HQSOFTComboBox<TData, TValue>`

**Đường dẫn:** [HQSOFTComboBox.razor](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor) + [.razor.cs](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs) (2.293 dòng)
**Namespace:** `HQSOFT.Xspire.Application.Blazor.Commons.Components.LazyCombobox`

### 4.2. Generic type

| Tham số | Giá trị | Lý do |
|---|---|---|
| `TData` | `CustomerComboboxItemDto` | Trùng kiểu trả về của `GetListComboboxDataPagedAsync` và `GetComboboxByIdAsync`. Không cần map. |
| `TValue` | **`Guid?`** | `DistributorOfTeamDetailUpdateDto.CustomerId` là `Guid?` ([DistributorOfTeamDetailUpdateDto.cs:13](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/DistributorOfTeamDetails/DistributorOfTeamDetailUpdateDto.cs#L13)). **Bắt buộc `Guid?`, không phải `Guid`** — vì cột này cho phép xóa (`ClearButtonDisplayMode.Auto`) và dòng mới khởi tạo với `CustomerId = null`. |

> SalesOrder dùng `TValue="Guid"` (non-nullable) vì `EditingDoc.CustomerXSId` là `Guid` bắt buộc. **Đừng copy nhầm chỗ này.**

### 4.3. Bảng property cần dùng

| Property | Giá trị đề xuất | Bắt buộc | Ghi chú |
|---|---|:---:|---|
| `TData` | `CustomerComboboxItemDto` | ✅ | |
| `TValue` | `Guid?` | ✅ | Khớp `CustomerId` |
| `Value` | `@editModel.CustomerId` | ✅ | **`editModel`, KHÔNG phải `EditingDistributorOfTeamDetail`** |
| `ValueExpression` | `@(() => editModel.CustomerId)` | ✅ | Cần cho `ValidationMessage` + `NotifyBoundFieldChangedAsync` |
| `ValueChanged` | `@(async (Guid? v) => await Grid_SelectCustomer(editModel, v))` | ✅ | **Phải capture `editModel`** |
| `ValueFieldName` | `@nameof(CustomerComboboxItemDto.Id)` | ✅ | |
| `TextFieldName` | `@nameof(CustomerComboboxItemDto.Code)` | ✅ | **Sửa bug hiện tại** (đang là `Description` trong cột "MÃ") |
| `LoadSelectedItemAsync` | `@LoadSelectedCustomerAsync` | ✅ | Fill ô khi mở doc cũ |
| `LoadCustomDataAsync` | `@LoadCustomersCustomDataAsync` | ✅ | Paging + search server |
| `DataLoadMode` | `ListDataLoadMode.OnDemand` | ⬜ | Đã là **default** ([razor.cs:348](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L348)) — viết ra cho tường minh |
| `ListRenderMode` | `ListRenderMode.Virtual` | ⬜ | Đã là **default** ([razor.cs:343](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L343)) |
| `SearchDelay` | `300` | ⬜ | Đã là default |
| `ClearButtonDisplayMode` | `DataEditorClearButtonDisplayMode.Auto` | ✅ | Giữ đúng hành vi hiện tại (cho phép xóa) |
| `EditFormat` / `DisplayFormat` | `"{0}"` | ⬜ | Đồng bộ SalesOrder / SalesRoute |
| `ShowValidationIcon` | `true` | ✅ | Giữ hành vi hiện tại |
| `Enabled` | `true` | ⬜ | |
| **`DependsOn`** | **KHÔNG dùng** | ⛔ | Xem cảnh báo bên dưới |
| **`EntityTypeForReload`** | **KHÔNG dùng** | ⛔ | Xem cảnh báo bên dưới |

### 4.4. ⛔ Hai property TUYỆT ĐỐI không dùng

**`DependsOn`** — [OnParametersSetAsync:467-513](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L467-L513):
```csharp
if (previousDependsOn != null && !Equals(Value, default(TValue)))
{
    _lastValue = default(TValue);
    await ValueChanged.InvokeAsync(default(TValue));   // ⚠️ TỰ ĐỘNG XOÁ CustomerId
}
```
Trong grid, mỗi lần re-render dòng có thể tạo `DependsOn` mới → component tưởng cascade đổi → **tự bắn `ValueChanged(null)` và xoá `CustomerId` của dòng**. Đây là kịch bản "chọn xong bị trắng" kinh điển. Khách hàng **không phụ thuộc Depot/SalesTeam** nên không có lý do nghiệp vụ nào cần `DependsOn`.

**`EntityTypeForReload`** — [OnInitialized:449-462](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L449-L462): đăng ký handler vào `ComboBoxCacheInvalidationService`. Trong grid, component bị tạo/hủy mỗi lần vào/ra edit cell → subscribe/unsubscribe liên tục, dễ rò rỉ và bắn `ReloadAsync` giữa lúc đang chọn.

### 4.5. Markup đề xuất

Thay thế [DistributorOfTeam.razor:226-245](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L226-L245):

```razor
<CellEditTemplate>
    @{
        var editModel = (DistributorOfTeamDetailUpdateDto)context.EditModel;
    }
    @if (editModel != null)
    {
        <HQSOFTComboBox TData="CustomerComboboxItemDto"
                        TValue="Guid?"
                        Value="@editModel.CustomerId"
                        ValueExpression="@(() => editModel.CustomerId)"
                        ValueChanged="@(async (Guid? newValue) => await Grid_SelectCustomer(editModel, newValue))"
                        ValueFieldName="@nameof(CustomerComboboxItemDto.Id)"
                        TextFieldName="@nameof(CustomerComboboxItemDto.Code)"
                        EditFormat="{0}"
                        DisplayFormat="{0}"
                        LoadSelectedItemAsync="@LoadSelectedCustomerAsync"
                        LoadCustomDataAsync="@LoadCustomersCustomDataAsync"
                        DataLoadMode="ListDataLoadMode.OnDemand"
                        ListRenderMode="ListRenderMode.Virtual"
                        SearchDelay="300"
                        ClearButtonDisplayMode="DataEditorClearButtonDisplayMode.Auto"
                        ShowValidationIcon="true">
            <Columns>
                <DxListEditorColumn FieldName="@nameof(CustomerComboboxItemDto.Code)" Caption="@L["Code"]" />
                <DxListEditorColumn FieldName="@nameof(CustomerComboboxItemDto.Description)" Caption="@L["Description"]" />
            </Columns>
        </HQSOFTComboBox>
    }
</CellEditTemplate>
```

Ba khác biệt so với commit `5045b3b46` đã revert:
1. Thêm guard `@if (editModel != null)` — chống `NullReferenceException` khi grid render transient (đúng như [SalesRoute.razor:324-326](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L324-L326) đang làm).
2. `ValueChanged` truyền `editModel` (đây là fix của `df7ccac29`).
3. **KHÔNG** có `EditingDistributorOfTeamDetail = editModel;` trong block `@{ }`.

### 4.6. Using cần thêm vào `.razor`

Kiểm tra file hiện tại — đã có sẵn `DevExtreme.AspNet.Data`, `DevExtreme.AspNet.Data.ResponseModel`, `System.Threading`, `HQSOFT.Xspire.MasterData.Customers`. Cần bổ sung (nếu `_Imports.razor` chưa có):
```razor
@using HQSOFT.Xspire.Application.Blazor.Commons.Components.LazyCombobox
@using HQSOFT.Xspire.Application.Blazor.Commons.Helper.LazyCombobox
@using HQSOFT.Xspire.MasterData.Shared
```

---

## 5. Cách triển khai `LoadSelectedCustomerAsync` (fill dữ liệu khi mở chứng từ cũ)

### 5.1. Cơ chế component gọi hàm này

Ba đường dẫn gọi trong `HQSOFTComboBox`:

1. **Khởi tạo binding lần đầu** — [OnParametersSetAsync:517-524](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L517-L524):
```csharp
if (!_parameterBindingInitialized)
{
    _parameterBindingInitialized = true;
    _lastBoundParameterValue = Value;
    _lastValue = Value;
    await LoadInitialDataAsync();      // → LoadSelectedItemAsync(Value)
    return;
}
```
→ Đây chính là đường fill ô khi **vào edit cell của dòng đã có `CustomerId`** (mở chứng từ cũ).

2. **Parent đổi `Value`** — [OnParametersSetAsync:527-534](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L527-L534).

3. **Resync text sau khi đóng dropdown / blur** — [razor.cs:1285, 1878-1890](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L1878-L1890).

Kết quả được đưa vào `ApplySelectedLoadResult` → set `_customDataEditText`, `_committedSelectionText`, và **ghim dòng vào chunk đầu** (`_pinnedSelectedRowForFirstChunk`) để dòng đang chọn luôn hiện trong dropdown dù nằm ở trang 47.

### 5.2. Cài đặt đề xuất

```csharp
// Server-side resolve item đã chọn theo Id — KHÔNG phụ thuộc danh sách đã nạp.
// GetComboboxByIdAsync không lọc Status ⇒ KH đã ngưng hoạt động vẫn hiển thị đúng
// khi mở chứng từ cũ (chỉ không xuất hiện trong dropdown để chọn mới).
private async Task<List<CustomerComboboxItemDto>> LoadSelectedCustomerAsync(Guid? customerId)
{
    if (!customerId.HasValue || customerId.Value == Guid.Empty)
        return new List<CustomerComboboxItemDto>();

    try
    {
        var item = await CustomersAppService.GetComboboxByIdAsync(customerId.Value);
        return item == null
            ? new List<CustomerComboboxItemDto>()
            : new List<CustomerComboboxItemDto> { item };
    }
    catch
    {
        // Không ném lỗi: component chỉ cần text hiển thị, hỏng lookup không được phá edit cell.
        return new List<CustomerComboboxItemDto>();
    }
}
```

### 5.3. Khác biệt so với commit `5045b3b46`

| | `5045b3b46` | Đề xuất |
|---|---|---|
| Signature `Guid?` | ✅ Đúng | ✅ Giữ |
| Guard `Guid.Empty` | ✅ | ✅ Giữ |
| `try/catch` | ❌ Thiếu | ✅ **Thêm** (SalesOrder có — [SalesOrder.razor.cs:12854-12865](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs#L12854-L12865)) |

Lý do bắt buộc thêm `try/catch`: hàm này được component gọi trong `OnParametersSetAsync`. Nếu ném exception khi mạng chập hoặc `AbpRemoteCallException`, **toàn bộ vòng render của grid sẽ hỏng**, không chỉ một ô.

### 5.4. Cân nhắc thêm cache (tùy chọn, khuyến nghị)

SalesOrder không gọi thẳng service mà qua `GetCustomerComboboxByIdCachedAsync`. Trong grid, khi người dùng bấm qua lại giữa các dòng, cùng một `CustomerId` sẽ bị resolve lặp lại. Nếu muốn tối ưu, thêm dictionary cấp trang:

```csharp
private readonly Dictionary<Guid, CustomerComboboxItemDto?> _customerComboCache = new();

private async Task<CustomerComboboxItemDto?> GetCustomerComboCachedAsync(Guid id)
{
    if (_customerComboCache.TryGetValue(id, out var cached)) return cached;
    var dto = await CustomersAppService.GetComboboxByIdAsync(id);
    _customerComboCache[id] = dto;
    return dto;
}
```
> Đây là **tối ưu, không phải điều kiện đúng/sai**. Có thể làm ở bước 2. Nếu làm, phải clear cache trong `LoadDataAsync`/`NewDataAsync` để tránh dữ liệu cũ sau khi KH được sửa ở màn hình khác.

---

## 6. Cách triển khai `LoadCustomersCustomDataAsync` (tìm kiếm/phân trang toàn bộ DB)

### 6.1. Cơ chế

DevExpress `DxComboBox.CustomData` gọi callback này với `DataSourceLoadOptionsBase` chứa `Skip`, `Take`, `Filter` mỗi khi: mở dropdown, cuộn tới cuối chunk, hoặc gõ tìm kiếm (sau `SearchDelay`).

`HQSOFTComboBox` **không gọi thẳng** callback của ta — nó bọc qua `HandleCustomDataAsync` ([razor.cs:1139-1142](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L1139-L1142)) để thêm: session cache theo lần mở dropdown, dedupe request trùng `skip/take/filter`, debounce khi gõ (`CustomDataTypingDebounceDelayMs = 180`), hủy request cũ bằng CTS, và merge dòng đã chọn vào chunk đầu. **Ta chỉ cần viết phần gọi API thuần.**

### 6.2. Cài đặt đề xuất

```csharp
// Phân trang + tìm kiếm khách hàng trên SERVER (toàn bộ DB), theo mẫu SalesOrder.
// ComboboxCustomDataHelper trích Skip/Take/FilterText từ DataSourceLoadOptions của DevExpress;
// GetListComboboxDataPagedAsync trả PagedResultDto có TotalCount thật ⇒ virtual scroll tính đúng.
private async Task<LoadResult> LoadCustomersCustomDataAsync(
    DataSourceLoadOptionsBase options,
    CancellationToken cancellationToken)
{
    cancellationToken.ThrowIfCancellationRequested();

    var input = ComboboxCustomDataHelper.ToComboboxInput(options);

    var page = await CustomersAppService.GetListComboboxDataPagedAsync(new GetComboboxDataInput
    {
        FilterText     = input.FilterText,
        SkipCount      = input.SkipCount,
        MaxResultCount = input.MaxResultCount
    });

    cancellationToken.ThrowIfCancellationRequested();

    return new LoadResult
    {
        data       = page.Items?.ToList() ?? new List<CustomerComboboxItemDto>(),
        totalCount = (int)page.TotalCount
    };
}
```

### 6.3. Ba khác biệt so với commit `5045b3b46` (đều quan trọng)

| # | `5045b3b46` | Đề xuất | Lý do |
|---|---|---|---|
| 1 | Truyền thẳng `input` từ helper | Tạo `GetComboboxDataInput` **mới**, chỉ copy 3 field | `ToComboboxInput` trả về object có thể mang field thừa; server `ApplyNormalizedPaging` sẽ **mutate** object đó. Tạo mới = an toàn, và đây đúng là điều SalesOrder làm ([BuildPagedCustomDataAsync](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs#L12825-L12847)). |
| 2 | `ThrowIfCancellationRequested()` chỉ **sau** await | Gọi **cả trước và sau** | Bỏ sớm request đã bị hủy (user gõ tiếp) → giảm tải server. SalesOrder có cả hai. |
| 3 | `page.Items.ToList()` | `page.Items?.ToList() ?? new List<...>()` | Chống `NullReferenceException` nếu API trả `Items = null`. |

### 6.4. ⚠️ KHÔNG dùng `ComboboxCustomDataHelper.ToLoadResult`

Helper này ([ComboboxCustomDataHelper.cs:52-61](src/HQSOFT.Xspire.Application.Blazor/Commons/Helper/LazyCombobox/ComboboxCustomDataHelper.cs#L52-L61)) tính `totalCount` **ước lượng** (`skip + count + 1`) cho các API **không trả tổng**:
```csharp
var totalCount = data.Count < requestedTake ? skip + data.Count : skip + data.Count + 1;
```
`GetListComboboxDataPagedAsync` **có** `TotalCount` thật → dùng `ToLoadResult` sẽ làm scrollbar nhảy loạn khi cuộn. Chỉ dùng `ToComboboxInput`.

### 6.5. Tìm kiếm hoạt động thế nào (end-to-end)

1. Người dùng gõ `"minh phat"` → DevExpress dựng `Filter` = `[["Code","contains","minh phat"],"or",["Description","contains","minh phat"]]`.
2. `TryExtractFilterSearchText` ([Helper:113-118](src/HQSOFT.Xspire.Application.Blazor/Commons/Helper/LazyCombobox/ComboboxCustomDataHelper.cs#L113-L118)) duyệt cây filter, `IsOrGroup` nhận ra OR cùng chuỗi → trả `"minh phat"`.
3. → `GetComboboxDataInput { FilterText = "minh phat", SkipCount = 0, MaxResultCount = 100 }`.
4. Server: `ApplyUnaccentFilter(filterText, e => e.Code, e => e.CustomerName)` → SQL bỏ dấu → khớp cả **"MINH PHÁT"**, **"Minh Phát"**, **"minh-phat"**.
5. `TotalCount` = tổng số khớp **trong toàn DB** (ví dụ 37) → DevExpress render đúng.
6. Cuộn xuống → `Skip=100`, `Take=100` với **cùng** `FilterText`.

→ **Tìm được khách hàng thứ 50.000 trong DB.** Đây chính là mục tiêu của yêu cầu.

---

## 7. Bind `Value`, `ValueExpression`, `ValueChanged` vào đúng `context.EditModel`

### 7.1. ⚠️ Đây là mục quan trọng nhất của toàn bộ tài liệu

Lỗi "chọn khách hàng xong bị trắng" trước đây **hoàn toàn nằm ở đây**, không phải ở paging.

### 7.2. Quy tắc bắt buộc

**Trong `CellEditTemplate`, khai báo biến local và dùng NÓ cho cả ba binding:**

```razor
<CellEditTemplate>
    @{
        var editModel = (DistributorOfTeamDetailUpdateDto)context.EditModel;
    }
    @if (editModel != null)
    {
        <HQSOFTComboBox ...
            Value="@editModel.CustomerId"                                                  <!-- ✅ -->
            ValueExpression="@(() => editModel.CustomerId)"                                <!-- ✅ -->
            ValueChanged="@(async (Guid? v) => await Grid_SelectCustomer(editModel, v))"   <!-- ✅ -->
            ... />
    }
</CellEditTemplate>
```

### 7.3. Bảng đúng/sai

| Binding | ✅ ĐÚNG | ❌ SAI |
|---|---|---|
| `Value` | `@editModel.CustomerId` | `@EditingDistributorOfTeamDetail.CustomerId` |
| `ValueExpression` | `@(() => editModel.CustomerId)` | `@(() => EditingDistributorOfTeamDetail.CustomerId)` |
| `ValueChanged` | `@(async v => await Grid_SelectCustomer(editModel, v))` | `@(v => Grid_SelectCustomer(v))` |

### 7.4. ⛔ TUYỆT ĐỐI không viết dòng này

```razor
@{
    EditingDistributorOfTeamDetail = (DistributorOfTeamDetailUpdateDto)context.EditModel;  // ⛔
}
```

Ba lý do:
1. **Side-effect trong render tree.** Block `@{ }` chạy mỗi lần render. Gán state global trong đó → thay đổi state trong lúc render → Blazor có thể phải render lại → **render loop**.
2. **Grid render nhiều dòng.** Dòng cuối được render sẽ "thắng" và ghi đè biến global. Nếu một async callback của dòng khác hoàn thành sau đó và đọc `EditingDistributorOfTeamDetail`, nó sẽ ghi vào **sai dòng**.
3. Đây chính là dòng **còn sót lại** trong commit `df7ccac29` ở [Grid_SelectCustomer](#131-nguyên-nhân-gốc-lỗi-chọn-xong-bị-trắng): `EditingDistributorOfTeamDetail = editModel;`.

Hiện tại các `CellEditTemplate` ở [razor:265](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L265) và [razor:350](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L350) **đang làm đúng dòng này** — và đó là lý do `Grid_SelectCustomer(Guid?)` "may mắn" chạy được. Khi chuyển sang truyền `editModel` tường minh, phải bỏ luôn cả các gán ngầm này.

### 7.5. Vì sao `ValueExpression` không thể bỏ

[NotifyBoundFieldChangedAsync](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L2046) dùng `ValueExpression` để dựng `FieldIdentifier` và báo `EditContext` field đã đổi. Thiếu nó:
- `ValidationMessage For=` không hoạt động;
- `e.ValidateFieldGuidRequired(nameof(item.CustomerId), ...)` ([razor.cs:1091](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1091)) có thể hiển thị lỗi sai thời điểm;
- `ShowValidationIcon="true"` không có gì để hiện.

### 7.6. Tiền lệ đã hoạt động trong codebase

[SalesRoute.razor:322-355](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L322-L355) — `HQSOFTComboBox` in-grid với `ValueChanged="@(async (Guid newValue) => await SelectMarket(editModel, newValue))"`, và [SelectMarket](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor.cs#L1723-L1745):
```csharp
private async Task SelectMarket(SalesRouteMasterUpdateDto editModel, Guid newValue)
{
    if (editModel == null) return;
    editModel.MarketId = newValue;
    editModel.MarketCode = null;
    ...
}
```
→ **Đây là mẫu chuẩn của dự án cho combobox lazy-load trong grid. Copy mẫu này.**

> Lưu ý: SalesRoute vẫn có `EditingSalesRouteMaster = editModel;` trong block `@{ }` ([razor:324](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L324)). Đó là phần **không nên** copy — nó đang "chạy được" nhưng cùng bản chất rủi ro. Phần đáng copy là `ValueChanged(editModel, v)` và guard `if (editModel == null) return;`.

---

## 8. Cập nhật `CustomerId` và `CustomerCode` sau khi chọn

### 8.1. Cài đặt đề xuất

```csharp
// editModel là context.EditModel của ĐÚNG dòng đang sửa (truyền từ CellEditTemplate).
// Không đụng tới EditingDistributorOfTeamDetail — tránh ghi nhầm dòng khi grid re-render.
private async Task Grid_SelectCustomer(DistributorOfTeamDetailUpdateDto editModel, Guid? guid)
{
    if (editModel == null) return;                       // guard: grid render transient

    editModel.CustomerId = guid;

    if (guid.HasValue && guid.Value != Guid.Empty)
    {
        try
        {
            var data = await CustomersAppService.GetComboboxByIdAsync(guid.Value);
            editModel.CustomerCode = data?.Code;          // null-safe: không ném khi lookup hỏng
        }
        catch
        {
            editModel.CustomerCode = null;                // không giữ mã của khách hàng cũ
        }
    }
    else
    {
        editModel.CustomerCode = null;                    // nhánh XOÁ — hiện tại đang thiếu
    }

    editModel.IsChanged = true;

    UpdateCustomerNumber();
    await MarkAsChanged(true);
    await SafeStateHasChangedAsync();
}
```

### 8.2. Bảng thay đổi so với hiện tại

| Điểm | Hiện tại ([razor.cs:899-917](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L899-L917)) | Đề xuất |
|---|---|---|
| Đích ghi | `EditingDistributorOfTeamDetail` (global) | `editModel` (tham số) |
| Nguồn `Code` | `CustomerCollection.FirstOrDefault(...)` | `await GetComboboxByIdAsync(...)` |
| Null-safety | `data.Code` → NRE | `data?.Code` |
| Nhánh xóa | **Không có** | `else { editModel.CustomerCode = null; }` |
| `catch` | Nuốt toàn bộ, im lặng | Chỉ bọc lời gọi API, set `null` tường minh |
| `IsChanged` | Không set | Set `true` |

### 8.3. Vì sao `GetComboboxByIdAsync` chứ không lấy từ dropdown

Component **không** trả về `TData` cho callback — `ValueChanged` chỉ có `TValue` (`Guid?`). Muốn lấy `Code` phải resolve lại. Đây cũng đúng vì `GetComboboxByIdAsync` **không lọc Status** (Mục 3.2) nên luôn resolve được, kể cả trong trường hợp biên.

Chi phí: **1 request nhỏ mỗi lần chọn khách**. Chấp nhận được, và có thể tối ưu bằng cache ở Mục 5.4.

### 8.4. Về `IsChanged`

Grid dùng `EditMode.EditCell` với `EditModelSaving` ([razor.cs:975-1020](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L975-L1020)) — hàm này đã set `editModel.IsChanged = true` khi commit cell. Việc set thêm trong `Grid_SelectCustomer` là **phòng thủ** cho trường hợp async callback hoàn tất sau khi cell đã commit. Không gây tác dụng phụ.

### 8.5. Về `UpdateCustomerNumber()`

[razor.cs:1128-1136](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1128-L1136) đếm distinct `CustomerId` trên `DistributorOfTeamDetailList`. Với dòng **mới**, `editModel` chưa nằm trong list (chỉ được `Add` tại `EditModelSaving` — [razor.cs:1010](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1010)) → `CustomerNumber` tạm thời chưa tính dòng đang thêm. **Đây là hành vi hiện tại, không đổi** khi chuyển sang lazy loading. Nếu muốn sửa thì là một issue độc lập, ngoài phạm vi.

---

## 9. Fill cột tên khách hàng không phụ thuộc `CustomerCollection`

### 9.1. Hiện trạng: chỉ còn 1 chỗ cần sửa

| Vị trí | Hiện tại | Cần làm |
|---|---|---|
| Cột MÃ — `CellDisplayTemplate` ([razor:194-205](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L194-L205)) | `HQSOFTCellDisplayTemplate` | ✅ Giữ nguyên |
| Cột TÊN — `CellDisplayTemplate` ([razor:251-261](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L251-L261)) | `HQSOFTCellDisplayTemplate` | ✅ Giữ nguyên |
| Cột TÊN — **`CellEditTemplate`** ([razor:263-280](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L263-L280)) | `CustomerCollection.FirstOrDefault(...)` | ❌ **PHẢI SỬA** |

### 9.2. Đoạn cần thay

```razor
<!-- HIỆN TẠI — phụ thuộc CustomerCollection, và có side-effect gán global -->
<CellEditTemplate>
    @{
        EditingDistributorOfTeamDetail = ((DistributorOfTeamDetailUpdateDto)context.EditModel);   // ⛔ side-effect
    }
    @if (EditingDistributorOfTeamDetail.CustomerId is Guid valueId)
    {
        var customer = CustomerCollection.FirstOrDefault(p => p.Id == valueId);                   // ⛔ giới hạn 1.000
        var CustomerName = customer?.Description ?? "";
        <div style="display: flex; align-items: center">
            <span class="margin-left: 5px;">@CustomerName</span>
        </div>
    }
    else
    {
        <span class="margin-left: 5px;"></span>
    }
</CellEditTemplate>
```

### 9.3. Đề xuất

```razor
<CellEditTemplate>
    @{
        var editModel = (DistributorOfTeamDetailUpdateDto)context.EditModel;
    }
    @if (editModel?.CustomerId is Guid valueId && valueId != Guid.Empty)
    {
        <HQSOFTCellDisplayTemplate TItem="CustomerDto"
                                   EntityId="@valueId"
                                   TableName="Customers"
                                   DisplayField="CustomerName"
                                   checkCellEdit="true" />
    }
    else
    {
        <span class="margin-left: 5px;"></span>
    }
</CellEditTemplate>
```

Bốn thay đổi:
1. Bỏ gán global `EditingDistributorOfTeamDetail`.
2. Thay `CustomerCollection` bằng `HQSOFTCellDisplayTemplate` (server lookup + cache).
3. Thêm `valueId != Guid.Empty` (khớp `CellDisplayTemplate` ở [razor:252](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L252)).
4. Dùng `checkCellEdit="true"` + **không truyền `CellContext`** — theo hợp đồng của component ([HQSOFTCellDisplayTemplate.razor:18-27](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/HQSOFTCellDisplayTemplate.razor#L18-L27)):
```razor
if (!checkCellEdit) { <CustomGridCellContent CellContext="CellContext" Text="@DisplayText" /> }
else                { <CustomGridCellContent checkEdit=true CellContext="null" Text="@DisplayText" /> }
```

> Lưu ý về commit `5045b3b46`: commit đó dùng `CellContext="context"` **mà không** có `checkCellEdit="true"`. Trong `CellEditTemplate`, `context` là `GridDataColumnCellEditTemplateContext`, **không phải** `GridDataColumnCellDisplayTemplateContext` mà `HQSOFTCellDisplayTemplate` khai báo — sẽ lỗi biên dịch hoặc render sai. **Đây là điểm phải sửa khi phục hồi commit đó.**

### 9.4. Cơ chế `HQSOFTCellDisplayTemplate` (vì sao an toàn)

[HQSOFTCellDisplayTemplate.razor:59-135](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/HQSOFTCellDisplayTemplate.razor#L59-L135):
- **Cache trước:** `DataQueryHelper.TryGetCachedEntity<TItem>` — hit thì trả ngay, 0 request.
- **Semaphore `DisplayLoadGate(20, 20)`** — tối đa 20 lookup song song, không làm sập server khi grid có 500 dòng.
- **Generation guard** (`_loadGeneration`) — kết quả trả về trễ của lần load cũ bị bỏ qua → **không có race condition khi cuộn nhanh**.
- **Memo tham số** (`_lastEntityId`, `_lastTableName`, ...) — không gọi lại khi re-render với cùng tham số → **không có render loop**.

### 9.5. Khuyến nghị preload (tối ưu, không bắt buộc)

Comment đầu file [HQSOFTCellDisplayTemplate.razor:1-8](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/HQSOFTCellDisplayTemplate.razor#L1-L8) hướng dẫn:
```csharp
var ids = rows.Select(r => r.CustomerId).Where(g => g != Guid.Empty).Distinct();
await DataQueryHelper.PreloadEntitiesAsync<CustomerDto>(ids, "Customers", fields: ...);
```
Có thể gọi trong `LoadDataAsync` sau khi có `DistributorOfTeamDetailList` → **1 request batch** thay vì N request lẻ khi mở chứng từ nhiều dòng. Đây là cải thiện hiệu năng đáng kể và **độc lập** với việc chuyển combobox.

Ngoài ra, contract đã có sẵn `GetListComboboxByDocIdsAsync(List<Guid> docIds)` ([ICustomersAppService.Extended.cs:18](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/Customers/ICustomersAppService.Extended.cs#L18)) với chú thích *"Chỉ các field combobox cho tập Id — tránh GetListComboboxDataAsync(10k) + filter client"* — chính là API dành cho mục đích này.

---

## 10. Ảnh hưởng đến việc chọn `SalesTeamId` / `SalesTeamCode`

### 10.1. Kết luận: **KHÔNG có ảnh hưởng trực tiếp.** Nhưng có 1 rủi ro gián tiếp phải xử lý.

### 10.2. SalesTeam là bài toán khác hẳn

SalesTeam **cascade theo Depot**:
```csharp
// razor.cs:731, 798, 862
SalesTeamComboBoxList = SalesTeamCollection.Where(st => st.DepotId == EditingDoc?.DepotId).OrderBy(st => st.Code).ToList();
```
Danh sách đội bán hàng đã được **lọc theo kho** nên thường chỉ vài chục dòng. `MaxResultCount = 1000` với `SalesTeamCollection` là **hợp lý** và **không cần đổi**. Việc lazy-load SalesTeam là công việc riêng, ngoài phạm vi yêu cầu.

### 10.3. ⚠️ Rủi ro gián tiếp: `EditingDistributorOfTeamDetail` dùng chung

`SelectedDepot` ([razor.cs:855-897](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L855-L897)) đang thao tác trên biến global:
```csharp
EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;   // dòng 866 và 883
foreach (var item in DistributorOfTeamDetailList.Where(p => !p.IsDeleted))
{
    item.SalesTeamId = null;
    item.SalesTeamCode = null;
    item.IsChanged = true;
}
if (DistributorOfTeamDetailGrid != null) DistributorOfTeamDetailGrid.Reload();
```

Sau khi bỏ các gán ngầm `EditingDistributorOfTeamDetail = context.EditModel` trong `CellEditTemplate` (Mục 7.4 và 9.3), biến này **chỉ còn được set bởi `OnFocusedRowChanged`** ([razor.cs:953-961](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L953-L961)) — trỏ tới **data item** của dòng focus, không phải **edit model**.

Hệ quả cụ thể: dòng `EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;` trong `SelectedDepot` sẽ ghi vào data item của dòng đang focus — **trùng lặp** với vòng `foreach` ngay bên dưới (vốn đã set `SalesTeamId = null` cho mọi dòng). Không gây mất `CustomerId`, nhưng gây **không nhất quán**: một dòng thành `Guid.Empty`, các dòng khác thành `null`.

**Khuyến nghị:** khi thực hiện, **bỏ hẳn** hai dòng `EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;` ở [razor.cs:866](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L866) và [razor.cs:883](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L883) — vòng `foreach` đã bao phủ đầy đủ. Đây là **dọn dẹp cần thiết**, không phải tùy chọn.

### 10.4. Điểm giao thoa nghiệp vụ: validate cặp (CustomerId, SalesTeamId)

[razor.cs:1077-1109](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1077-L1109) và [razor.cs:612-630](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L612-L630) kiểm tra trùng cặp:
```csharp
string uniqueKey = $"{item.CustomerId}_{item.SalesTeamId}";
```
→ Chỉ so sánh `Guid`, **không đọc `CustomerCollection`** → **không bị ảnh hưởng** bởi thay đổi. ✅

### 10.5. `Grid_SelectSalesTeam` — nên đồng bộ hoá signature

[razor.cs:919-937](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L919-L937) có **cùng lỗi thiết kế** với `Grid_SelectCustomer` cũ:
```csharp
private async Task Grid_SelectSalesTeam(Guid? guid)
{
    EditingDistributorOfTeamDetail.SalesTeamId = guid;                   // global
    var data = SalesTeamCollection.FirstOrDefault(p => p.Id == guid);
    EditingDistributorOfTeamDetail.SalesTeamCode = data.Code;            // NRE nếu null
}
```

Sau khi bỏ gán ngầm ở `CellEditTemplate` cột MÃ KHÁCH HÀNG và cột TÊN KHÁCH HÀNG, `CellEditTemplate` của cột **TÊN ĐỘI BÁN HÀNG** ([razor:349-351](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L349-L351)) **vẫn còn** gán `EditingDistributorOfTeamDetail = context.EditModel`, nên `Grid_SelectSalesTeam` **vẫn hoạt động**.

Tuy nhiên đây là coupling ngầm còn sót. **Khuyến nghị đổi cùng lúc** (thay đổi nhỏ, cùng pattern, tránh để lại nửa vời):
```csharp
private async Task Grid_SelectSalesTeam(DistributorOfTeamDetailUpdateDto editModel, Guid? guid)
{
    if (editModel == null) return;
    editModel.SalesTeamId = guid;
    editModel.SalesTeamCode = (guid.HasValue && guid.Value != Guid.Empty)
        ? SalesTeamCollection.FirstOrDefault(p => p.Id == guid)?.Code
        : null;
    editModel.IsChanged = true;
    UpdateCustomerNumber();
    await MarkAsChanged(true);
    await SafeStateHasChangedAsync();
}
```
(Vẫn dùng `SalesTeamCollection` — **không** chuyển SalesTeam sang lazy loading.)

> Nếu muốn giữ phạm vi tối thiểu tuyệt đối, có thể bỏ qua 10.5 — nhưng **10.3 thì bắt buộc**.

---

## 11. Xử lý khi xóa khách hàng đã chọn

### 11.1. Bug hiện tại

```csharp
if (guid != null)                       // chỉ có nhánh TRUE
{
    EditingDistributorOfTeamDetail.CustomerId = guid;
    ...
}
// KHÔNG có else ⇒ khi guid == null, CustomerId và CustomerCode giữ nguyên giá trị cũ
```
→ Bấm nút X: UI xóa text, nhưng **`CustomerId` và `CustomerCode` trong model không đổi**. Lưu lại thì khách hàng vẫn còn. Bug thực sự đang tồn tại.

### 11.2. Cách component xử lý nút X

`HQSOFTComboBox` có hai đường xóa:

**(a) `ClearButtonDisplayMode.Auto`** → DevExpress bắn `ValueChanged(default(TValue))` = `ValueChanged(null)` với `TValue = Guid?`.

**(b) Nút clear tùy chỉnh** (`ShowCustomClearButton`) → `HandleCustomClearButtonClick`, dùng cờ `_clearingInProgress` ([razor.cs:1989-1993](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L1989-L1993)) để chặn `ValueChanged(null)` giả từ `HideDropDown()`, rồi bắn `ValueChanged` một lần duy nhất.

→ Với `ClearButtonDisplayMode.Auto` (đường (a)), callback của ta nhận `null` **đúng một lần**.

### 11.3. ⚠️ Cơ chế bảo vệ `TryGetPreservedValueWhenSpuriousClear`

[razor.cs:1994-2036](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L1994-L2036):
```csharp
// CustomData / re-render: DxComboBox đôi khi bắn ValueChanged rỗng —
// không bubble null khi vẫn còn Id trong Value hoặc _lastValue
if (TryGetPreservedValueWhenSpuriousClear(newValue, out var preserved))
{
    _lastValue = preserved;
    await SynchronizeCurrentDataWithValueAsync(preserved);
    if (!IsValidValueForSelectedItemLoad(Value) && IsValidValueForSelectedItemLoad(preserved))
    {
        _lastBoundParameterValue = preserved;
        await ValueChanged.InvokeAsync(preserved);        // ĐẨY LẠI giá trị cũ
    }
    return;                                               // KHÔNG bubble null
}
```

**Đây là cơ chế chống mất dữ liệu** khi DevExpress bắn `ValueChanged(null)` giả trong lúc re-render — chính xác là kịch bản "chọn xong bị trắng".

**Cần kiểm thử kỹ:** khi người dùng **thực sự** bấm X, liệu heuristic này có nhầm là "spurious clear" và **chặn** thao tác xóa hợp lệ không? Đây là điểm rủi ro cao nhất của phương án và phải test bằng tay (mục 15.7).

**Phương án dự phòng nếu xóa không ăn:** đổi sang nút clear tùy chỉnh của component:
```razor
ShowCustomClearButton="true"
ClearButtonDisplayMode="DataEditorClearButtonDisplayMode.Never"
```
Đường này đi qua `HandleCustomClearButtonClick` với cờ `_clearingInProgress`, không qua heuristic trên → xóa luôn ăn.

### 11.4. Nhánh xử lý trong `Grid_SelectCustomer`

Đã có ở Mục 8.1:
```csharp
else
{
    editModel.CustomerCode = null;
}
```
Cộng với `editModel.CustomerId = guid;` (đã set `null`) ở đầu hàm → cả hai field được clear đúng.

### 11.5. Tương tác với validation

Sau khi xóa, `CustomerId == null` → `e.ValidateFieldGuidRequired(nameof(item.CustomerId), item.CustomerId, L)` ([razor.cs:1091](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1091)) sẽ báo lỗi bắt buộc khi lưu. **Đúng nghiệp vụ** — cột này là bắt buộc. Người dùng xóa rồi phải chọn lại hoặc xóa cả dòng.

### 11.6. Tương tác với `UpdateCustomerNumber`

[razor.cs:1128-1136](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1128-L1136) — đếm distinct `CustomerId`. Cần xác nhận hàm này lọc `null` (nếu `Select(p => p.CustomerId).Distinct().Count()` thì `null` sẽ được đếm là 1 giá trị). **Hành vi này không đổi so với hiện tại**, nhưng đáng kiểm tra trong lúc test (mục 15.7).

---

## 12. Race condition / render-loop

### 12.1. Bảng rủi ro

| # | Rủi ro | Nguyên nhân | Component đã xử lý? | Việc ta phải làm |
|---|---|---|:---:|---|
| R1 | **Ghi nhầm dòng** | Callback ghi vào global thay vì `editModel` | ❌ Không | Truyền `editModel` (Mục 7, 8) |
| R2 | **Render loop** | Gán state trong block `@{ }` của render tree | ❌ Không | Bỏ `EditingDistributorOfTeamDetail = context.EditModel` |
| R3 | Response cũ ghi đè text mới | Nhiều HTTP trả về sai thứ tự | ✅ `_selectedItemLoadGeneration` | Không |
| R4 | Gọi API lặp khi cuộn | DevExpress bắn request trùng | ✅ `_customDataCoalesce` + `_customDataResultCache` | Không |
| R5 | Request thừa khi gõ | Mỗi phím một request | ✅ debounce 180ms + `SearchDelay=300` | Không |
| R6 | Mất selection khi mở dropdown | Chunk đầu không chứa dòng đã chọn | ✅ `_pinnedSelectedRowForFirstChunk` | Không |
| R7 | **`ValueChanged(null)` giả** | DevExpress re-render | ✅ `TryGetPreservedValueWhenSpuriousClear` | Test kỹ (Mục 11.3) |
| R8 | `LoadInitialDataAsync` gọi lặp | Parent re-render | ✅ `_lastBoundParameterValue` set trước khi bubble | Không |
| R9 | **`Reload()` giữa lúc đang chọn** | `SelectedDepot` gọi `Grid.Reload()` | ❌ Không | Xem R9 bên dưới |
| R10 | **Cascade `DependsOn` xóa FK** | `DependsOn` đổi trong grid | ❌ Không | **Không dùng `DependsOn`** |
| R11 | Rò rỉ subscription | `EntityTypeForReload` trong grid | ❌ Không | **Không dùng `EntityTypeForReload`** |
| R12 | Async callback sau khi dòng bị hủy | `await GetComboboxByIdAsync` xong thì cell đã đóng | ⚠️ Một phần | Guard `if (editModel == null) return;` |

### 12.2. R1 + R2 — nguyên nhân gốc lỗi "chọn xong bị trắng"

**Chuỗi sự kiện đã xảy ra:**
```
1. User mở edit cell dòng 3 → CellEditTemplate render
2. Block @{ } chạy: EditingDistributorOfTeamDetail = editModel(dòng 3)
3. User chọn khách → HandleValueChanged → await SynchronizeCurrentDataWithValueAsync (HTTP)
4. Trong lúc await: StateHasChanged → grid re-render TẤT CẢ dòng
5. Block @{ } của dòng KHÁC chạy: EditingDistributorOfTeamDetail = editModel(dòng khác)   ⚠️
6. await hoàn tất → ValueChanged.InvokeAsync → Grid_SelectCustomer(guid)
7. Grid_SelectCustomer ghi vào EditingDistributorOfTeamDetail = editModel(dòng KHÁC)      ⚠️
8. Dòng 3: CustomerId vẫn null → Value=null → ô TRẮNG                                     ❌
```

**Vì sao `df7ccac29` vẫn có thể chưa hết lỗi:** commit đó sửa signature thành `Grid_SelectCustomer(editModel, guid)` — bước 7 đã đúng. **Nhưng** vẫn giữ:
```csharp
EditingDistributorOfTeamDetail = editModel;   // dòng đầu trong Grid_SelectCustomer
```
và **vẫn giữ** `EditingDistributorOfTeamDetail = context.EditModel` trong các `CellEditTemplate` khác ([razor:350](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L350)). Biến global vẫn bị ghi trong render tree → R2 vẫn còn → còn khả năng tái nhiễm.

**→ Fix hoàn chỉnh = `df7ccac29` + bỏ TẤT CẢ các gán `EditingDistributorOfTeamDetail` trong render tree và trong callback.**

### 12.3. R9 — `Reload()` giữa lúc đang chọn

`SelectedDepot` ([razor.cs:879, 894](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L879)) gọi `DistributorOfTeamDetailGrid.Reload()`. Nếu người dùng đang mở dropdown khách hàng và đổi Depot ở header:
- `Reload()` → grid dựng lại → `HQSOFTComboBox` bị **dispose**;
- `Dispose()` ([razor.cs:2251-2290](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L2251-L2290)) set `_disposed = true`, tăng generation, và `LoadSelectedItemAsync = null`;
- Mọi callback đang chạy kiểm tra `if (_disposed) return;` → **an toàn**, không ném exception.

Nhưng `Grid_SelectCustomer` của ta có thể vẫn đang `await GetComboboxByIdAsync` → khi xong sẽ ghi vào `editModel` đã bị bỏ. **Không crash** (chỉ ghi vào object mồ côi), nhưng guard `if (editModel == null) return;` là cần thiết cho trường hợp `context.EditModel` là `null`.

Đây là **rủi ro thấp** (đổi Depot trong lúc đang chọn khách là thao tác hiếm) và **đã tồn tại sẵn** trong code hiện tại. Không cần xử lý thêm ngoài guard.

### 12.4. R12 — guard bắt buộc

```csharp
if (editModel == null) return;
```
Bắt buộc vì DevExpress có thể render `CellEditTemplate` với `context.EditModel == null` trong khoảnh khắc chuyển trạng thái. `SalesRoute` ([razor:324-326](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L324-L326) và [razor.cs:1725-1728](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor.cs#L1725-L1728)) đã làm ở **cả hai** nơi (markup và callback). Làm theo.

### 12.5. Về `SafeStateHasChangedAsync`

`Grid_SelectCustomer` gọi `SafeStateHasChangedAsync()` ở cuối. `HandleValueChanged` của component **cũng** gọi `StateHasChanged` sau khi bubble ([razor.cs:2060-2064](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L2060-L2064)) → **2 lần render**. Không phải loop (component có `_lastBoundParameterValue` chặn re-load), chỉ là dư thừa nhẹ. Giữ nguyên để không đổi hành vi các phần khác của trang.

---

## 13. Thay đổi tối thiểu theo từng file / method

> Tổng: **2 file**, **3 vùng markup**, **3 method**. Không đụng backend, không đụng component dùng chung.

### 13.1. File 1 — `DistributorOfTeam.razor`

| # | Vị trí | Thay đổi | Bắt buộc |
|---|---|---|:---:|
| M1 | [226-245](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L226-L245) — `CellEditTemplate` cột MÃ KHÁCH HÀNG | `DxComboBox` → `HQSOFTComboBox` (markup Mục 4.5). Thêm guard `@if (editModel != null)`. `TextFieldName`: `Description` → `Code`. | ✅ |
| M2 | [263-280](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L263-L280) — `CellEditTemplate` cột TÊN KHÁCH HÀNG | `CustomerCollection.FirstOrDefault` → `HQSOFTCellDisplayTemplate` + `checkCellEdit="true"`. Bỏ gán `EditingDistributorOfTeamDetail`. (Mục 9.3) | ✅ |
| M3 | [349-351](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L349-L351) — `CellEditTemplate` cột TÊN ĐỘI BÁN HÀNG | Bỏ gán `EditingDistributorOfTeamDetail = context.EditModel`, dùng `var editModel` local. Cần làm cùng nếu áp dụng 10.5. | ⚠️ |
| M4 | [303-318](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L303-L318) — combobox SalesTeam | `ValueChanged` → `Grid_SelectSalesTeam(editModel, newValue)`. Chỉ khi áp dụng 10.5. | ⬜ |
| M5 | Vùng `@using` đầu file | Thêm `LazyCombobox` component + helper namespace (nếu `_Imports` chưa có) | ✅ |
| M6 | [209-224](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L209-L224) | Xóa block comment `HQSOFTDynamicComboBox` chết | ⬜ |

### 13.2. File 2 — `DistributorOfTeam.razor.cs`

| # | Method / vị trí | Thay đổi | Bắt buộc |
|---|---|---|:---:|
| C1 | [78](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L78) — field `CustomerCollection` | **Xóa** | ✅ |
| C2 | [751-755](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L751-L755) `GetCollectionAsync` | **Xóa dòng nạp `CustomerCollection`**. Giữ nguyên `SalesTeamCollection`. | ✅ |
| C3 | Vùng gần [848](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L848) (cạnh `LoadDepotsCustomDataAsync`) | **Thêm mới** `LoadSelectedCustomerAsync` (Mục 5.2) | ✅ |
| C4 | Ngay sau C3 | **Thêm mới** `LoadCustomersCustomDataAsync` (Mục 6.2) | ✅ |
| C5 | [899-917](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L899-L917) `Grid_SelectCustomer` | **Đổi signature** `(DistributorOfTeamDetailUpdateDto editModel, Guid? guid)` + toàn bộ thân hàm (Mục 8.1) | ✅ |
| C6 | [866](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L866), [883](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L883) trong `SelectedDepot` | **Xóa** `EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;` (Mục 10.3) | ✅ |
| C7 | [939-947](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L939-L947) | **Xóa** block comment `Grid_LoadCustomer` chết | ⬜ |
| C8 | [919-937](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L919-L937) `Grid_SelectSalesTeam` | Đổi signature nhận `editModel` (Mục 10.5) | ⚠️ |
| C9 | `using` đầu file | Thêm `DevExtreme.AspNet.Data`, `.ResponseModel`, `System.Threading`, `Commons.Helper.LazyCombobox`, `MasterData.Shared` (kiểm tra — phần lớn đã có) | ✅ |

### 13.3. Thứ tự thực hiện đề xuất

1. **C3 + C4** — thêm 2 method mới (chưa ai gọi, build vẫn xanh).
2. **C5 + C6** — sửa `Grid_SelectCustomer`, dọn `SelectedDepot`.
3. **M1** — thay combobox. Build + test ngay (mục 15.1–15.5).
4. **M2** — thay `CellEditTemplate` cột TÊN. Test 15.5, 15.9.
5. **C1 + C2** — xóa `CustomerCollection` (compiler sẽ báo nếu còn sót chỗ dùng).
6. **C6/M3/M4/C8 (10.5)** — dọn dẹp SalesTeam nếu làm.
7. **M6 + C7** — xóa code chết.

### 13.4. Không thay đổi

- ❌ `HQSOFTComboBox.razor` / `.razor.cs` — dùng nguyên trạng.
- ❌ `ComboboxCustomDataHelper.cs` — dùng nguyên trạng.
- ❌ `CustomersAppService*.cs`, `ICustomersAppService*.cs` — API đã đủ.
- ❌ `EfCoreCustomerRepository*.cs` — query đã đúng.
- ❌ `ComboboxDataLimits.cs`, `GetComboboxDataInput.cs`, `CustomerComboboxItemDto.cs`.
- ❌ `DistributorOfTeamListView.razor*` — không liên quan.
- ❌ `SalesOrder.razor*` — chỉ là mẫu tham chiếu.

---

## 14. Phục hồi từ implementation cũ: nên và không nên

### 14.1. ✅ NÊN phục hồi (từ `5045b3b46` + `df7ccac29`)

| # | Đoạn code | Từ commit | Điều chỉnh |
|---|---|---|---|
| P1 | `LoadCustomersCustomDataAsync` | `5045b3b46` | **Thêm** `ThrowIfCancellationRequested()` đầu hàm; tạo `GetComboboxDataInput` mới; `page.Items?.ToList() ?? new()` |
| P2 | `LoadSelectedCustomerAsync` | `5045b3b46` | **Thêm** `try/catch` trả list rỗng |
| P3 | Markup `HQSOFTComboBox` cột MÃ | `5045b3b46` | **Thêm** guard `@if (editModel != null)` |
| P4 | Xóa field `CustomerCollection` + dòng nạp trong `GetCollectionAsync` | `5045b3b46` | Nguyên trạng ✅ |
| P5 | `TextFieldName="@nameof(CustomerComboboxItemDto.Code)"` | `5045b3b46` | Nguyên trạng ✅ — sửa luôn bug hiển thị |
| P6 | Thêm `valueId != Guid.Empty` trong `CellEditTemplate` cột TÊN | `5045b3b46` | Nguyên trạng ✅ |
| P7 | **`ValueChanged` truyền `editModel`** | **`df7ccac29`** | Nguyên trạng ✅ — **đây là fix cốt lõi** |
| P8 | **Signature `Grid_SelectCustomer(editModel, guid)`** + nhánh `else` clear `CustomerCode` | **`df7ccac29`** | **Bỏ** dòng `EditingDistributorOfTeamDetail = editModel;` |

### 14.2. ⛔ KHÔNG NÊN phục hồi

| # | Đoạn code | Từ commit | Lý do |
|---|---|---|---|
| N1 | `EditingDistributorOfTeamDetail = editModel;` (dòng đầu `Grid_SelectCustomer`) | `df7ccac29` | **Nguồn tái nhiễm lỗi trắng ô.** Vẫn ghi state global từ đường async — R1/R2 ở Mục 12. Đây là dòng bị sót. |
| N2 | `<HQSOFTCellDisplayTemplate ... CellContext="context" />` trong `CellEditTemplate` | `5045b3b46` | Sai kiểu context. `CellEditTemplate` cung cấp `GridDataColumnCellEditTemplateContext`, component nhận `GridDataColumnCellDisplayTemplateContext`. **Phải** dùng `checkCellEdit="true"` và **bỏ** `CellContext`. (Mục 9.3) |
| N3 | Markup không có guard `@if (editModel != null)` | `5045b3b46` | Nguy cơ NRE khi grid render transient |
| N4 | `LoadSelectedCustomerAsync` không `try/catch` | `5045b3b46` | Exception trong `OnParametersSetAsync` phá vòng render toàn grid |
| N5 | `page.Items.ToList()` không null-check | `5045b3b46` | NRE tiềm ẩn |
| N6 | **Toàn bộ `63b76acb1`** | `63b76acb1` | Đây là commit **revert**, đưa về lại `CustomerCollection` 1.000 — chính là vấn đề cần giải quyết |
| N7 | Block comment `HQSOFTDynamicComboBox` ([razor:209-224](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L209-L224)) | — | Code chết, thuộc component khác (`HQSOFTDynamicComboBox`, không phải `HQSOFTComboBox`). Xóa. |
| N8 | Block comment `Grid_LoadCustomer` ([razor.cs:939-947](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L939-L947)) | `63b76acb1` | Code chết dùng `GetListDataAsNoTrackingAsync` 1.000. Xóa. |

### 14.3. ⚠️ Đoạn KHÔNG có trong commit cũ nhưng bắt buộc phải thêm

Đây là phần giải thích **vì sao chỉ revert `63b76acb1` là chưa đủ**:

| # | Việc cần thêm | Không có trong commit nào | Mục |
|---|---|---|---|
| A1 | Bỏ `EditingDistributorOfTeamDetail = context.EditModel` khỏi **mọi** `CellEditTemplate` (cột TÊN KHÁCH HÀNG và TÊN ĐỘI BÁN HÀNG) | ✅ Chưa từng làm | 7.4, 9.3 |
| A2 | Bỏ `EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;` trong `SelectedDepot` | ✅ Chưa từng làm | 10.3 |
| A3 | Guard `if (editModel == null) return;` trong callback | ✅ Chưa từng làm | 12.4 |
| A4 | `editModel.IsChanged = true;` trong `Grid_SelectCustomer` | ✅ Chưa từng làm | 8.4 |
| A5 | `checkCellEdit="true"` thay cho `CellContext="context"` | ✅ Chưa từng làm | 9.3 |

> **Đây là kết luận quan trọng nhất của Mục 14:** commit `df7ccac29` sửa **một nửa** vấn đề (callback), nhưng bỏ sót **nửa còn lại** (side-effect gán global trong render tree). Đó nhiều khả năng là lý do tác giả tiếp tục gặp lỗi và revert bằng `63b76acb1` chỉ 10 phút sau (17:22 → 17:32). Nếu chỉ revert lại `63b76acb1`, **lỗi sẽ tái xuất hiện**.

---

## 15. Checklist kiểm thử

> Chuẩn bị: DB có **> 1.000** khách hàng `Status` hoạt động. Ghi lại `Code` của một KH nằm ở vị trí ~2.000+ theo sort mặc định (gọi là **KH-X**). Mở DevTools → Network để đếm request.

### 15.1. Thêm dòng mới
- [ ] Chọn Depot ở header trước.
- [ ] Bấm **Thêm** → dòng mới xuất hiện ở cuối, `Idx` tăng đúng.
- [ ] `StartDate` / `EndDate` = hôm nay; `Status` = "A".
- [ ] `SalesTeamId`/`SalesTeamCode` kế thừa từ dòng cuối (logic [razor.cs:1044-1048](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1044-L1048)).
- [ ] Ô MÃ KHÁCH HÀNG **trống**, không lỗi console.
- [ ] Nếu chưa chọn Depot → cảnh báo `Msg:Validation.DepotRequired` vẫn hiện.

### 15.2. Chọn khách
- [ ] Click ô MÃ KHÁCH HÀNG → dropdown mở, hiện ~100–200 dòng (**không** 1.000).
- [ ] Network: **1 request** `GetListComboboxDataPagedAsync` với `SkipCount=0`, `MaxResultCount=100..200`.
- [ ] Chọn 1 khách → ô hiển thị **MÃ** (không phải tên) → xác nhận `TextFieldName="Code"` đúng.
- [ ] Cột TÊN KHÁCH HÀNG (edit mode) hiển thị **đúng tên** ngay lập tức.
- [ ] **Ô KHÔNG BỊ TRẮNG** ← *kiểm thử then chốt, chính là lỗi cũ*.
- [ ] Tab sang ô khác rồi quay lại → giá trị **vẫn còn**.
- [ ] Chọn khách ở **dòng 1**, rồi chọn khách khác ở **dòng 2** → dòng 1 **không bị đổi/mất** ← *kiểm thử R1*.

### 15.3. Tìm khách ngoài 1.000 bản ghi đầu
- [ ] Gõ mã **KH-X** → **tìm thấy** ← *mục tiêu chính của toàn bộ thay đổi*.
- [ ] Chọn KH-X → `CustomerId` + `CustomerCode` set đúng.
- [ ] Gõ tên tiếng Việt **không dấu** (vd `"sai gon"`) → khớp `"SÀI GÒN"` ← *`ApplyUnaccentFilter`*.
- [ ] Gõ tên **có dấu** → cũng khớp.
- [ ] Network: mỗi lần gõ chỉ **1 request** sau khi ngừng gõ ~300ms (không phải mỗi ký tự) ← *`SearchDelay` + debounce 180ms*.
- [ ] Gõ chuỗi vô nghĩa (`"zzzqqq"`) → dropdown rỗng, không lỗi.
- [ ] Xóa text tìm kiếm → danh sách quay về trang đầu.
- [ ] **Quick-resolve:** paste đúng mã KH-X vào ô + nhấn **Tab** → tự động chọn, ô hiển thị mã ← *tính năng mới có sẵn của `HQSOFTComboBox`*.

### 15.4. Cuộn nhiều trang
- [ ] Mở dropdown, cuộn xuống liên tục → dữ liệu load thêm mượt, không nhảy.
- [ ] Network: `SkipCount` tăng đều 0 → 100/200 → 200/400 → ... (**không** lặp `SkipCount=0`).
- [ ] Cuộn **ngược lên** → **không** phát sinh request mới ← *`_customDataResultCache`*.
- [ ] Cuộn xuống ~10 trang, chọn 1 khách ở trang 10 → ô hiển thị đúng.
- [ ] Đóng dropdown, mở lại → **dòng đã chọn xuất hiện ở đầu danh sách** ← *`_pinnedSelectedRowForFirstChunk`*.
- [ ] Thanh cuộn có tỉ lệ hợp lý so với tổng số KH ← *`TotalCount` thật*.
- [ ] Cuộn tới cuối cùng → dừng đúng, không request vô hạn.

### 15.5. Mở dữ liệu cũ
- [ ] Mở chứng từ đã lưu có nhiều dòng → **cột MÃ và TÊN hiển thị đầy đủ ngay** (`HQSOFTCellDisplayTemplate`).
- [ ] Click vào ô MÃ của một dòng → combobox **hiện sẵn mã**, không trắng ← *`LoadSelectedItemAsync`*.
- [ ] Cột TÊN ở chế độ edit hiện **đúng tên**.
- [ ] Mở chứng từ có `CustomerId` là **KH-X** (ngoài 1.000) → hiển thị **đúng** ← *lỗi cũ: trắng*.
- [ ] Mở chứng từ có KH đã **ngưng hoạt động** → **vẫn hiển thị mã/tên** ← *`GetComboboxByIdAsync` không lọc Status* (Mục 3.2). Xác nhận KH đó **không** xuất hiện trong dropdown.
- [ ] Network khi mở: **1 request/dòng** (hoặc ít hơn nếu trùng `CustomerId`), không có request 1.000 dòng.
- [ ] Mở chứng từ 50+ dòng → không timeout ← *`DisplayLoadGate(20,20)`*.

### 15.6. Đổi khách
- [ ] Ô đã có khách A → mở dropdown → khách A **được ghim ở đầu**.
- [ ] Chọn khách B → ô đổi sang B, `CustomerCode` = mã B.
- [ ] Cột TÊN đổi sang tên B.
- [ ] Đổi liên tiếp A → B → C nhanh → **giá trị cuối cùng là C**, không nhảy về A/B ← *`_selectedItemLoadGeneration`*.
- [ ] Đổi khách ở dòng 1, dòng 2, dòng 3 lần lượt → cả 3 dòng đúng, độc lập ← *R1*.

### 15.7. Xóa khách
- [ ] Ô có khách → nút X hiện (`ClearButtonDisplayMode.Auto`).
- [ ] Bấm X → ô **trống** ← *rủi ro `TryGetPreservedValueWhenSpuriousClear` chặn nhầm* (Mục 11.3).
- [ ] `CustomerId == null` **và** `CustomerCode == null` (kiểm bằng debug/log hoặc lưu rồi kiểm DB).
- [ ] Cột TÊN (edit mode) → **trống**.
- [ ] Lưu → validation báo lỗi bắt buộc `CustomerId` ← *đúng nghiệp vụ*.
- [ ] Xóa rồi chọn lại khách khác → giá trị mới ăn đúng.
- [ ] Kiểm `CustomerNumber` ở header sau khi xóa (Mục 11.6).
- [ ] Nếu xóa **không** ăn → chuyển sang `ShowCustomClearButton="true"` + `ClearButtonDisplayMode="Never"` (Mục 11.3).

### 15.8. Chọn đội bán hàng
- [ ] Chọn Depot ở header → `SalesTeamComboBoxList` lọc đúng theo Depot.
- [ ] Dropdown đội bán hàng vẫn hoạt động bình thường (**không** bị đổi sang lazy loading).
- [ ] Chọn đội → `SalesTeamId` + `SalesTeamCode` đúng dòng.
- [ ] Chọn khách rồi chọn đội **trên cùng dòng** → **cả hai đều giữ giá trị** ← *R1 chéo field*.
- [ ] **Đổi Depot ở header** khi lưới đã có dữ liệu → tất cả `SalesTeamId`/`SalesTeamCode` bị clear, **`CustomerId` GIỮ NGUYÊN** ← *kiểm thử `SelectedDepot`, Mục 10.3*.
- [ ] Sau khi đổi Depot: `Grid.Reload()` chạy, cột MÃ/TÊN khách hàng **vẫn hiển thị đủ**.
- [ ] Trùng cặp (Customer, SalesTeam) → validation báo lỗi ← *[razor.cs:1077-1109](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L1077-L1109)*.

### 15.9. Lưu và mở lại
- [ ] Thêm 3 dòng: 1 KH trong 1.000 đầu, 1 KH-X ngoài 1.000, 1 KH tìm bằng chuỗi không dấu.
- [ ] Lưu → thành công, không lỗi validation ngoài dự kiến.
- [ ] **Kiểm DB**: `CustomerId` và `CustomerCode` đúng cho cả 3 dòng ← *xác nhận Mục 8 hoạt động*.
- [ ] Đóng tab, mở lại chứng từ → cả 3 dòng hiển thị đúng mã + tên.
- [ ] Vào edit từng ô → combobox fill sẵn đúng.
- [ ] Sửa 1 dòng, lưu lại → chỉ dòng đó `IsChanged`, các dòng khác không bị đụng.
- [ ] `CustomerNumber` ở header khớp số KH distinct.
- [ ] **Duplicate** chứng từ (`?duplicateFrom=`) → detail copy đúng, hiển thị đủ ← *[razor.cs:280-305](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L280-L305)*.

### 15.10. Kiểm thử hiệu năng / hồi quy
- [ ] Mở trang lần đầu: **KHÔNG** còn request `GetListComboboxDataAsync` với `MaxResultCount=1000` ← *xác nhận C2*.
- [ ] So sánh thời gian tải trang trước/sau → phải **nhanh hơn**.
- [ ] Mở 5 tab chứng từ cùng lúc → không chậm bất thường (bộ nhớ giảm 5×1.000 DTO).
- [ ] Console **sạch**, không có warning render loop / "already rendering".
- [ ] Thao tác nhanh liên tục 30 giây (mở/đóng dropdown, cuộn, chọn) → **không treo, không lỗi**.
- [ ] `DistributorOfTeamListView` không bị ảnh hưởng.

---

## 16. Kết luận về ảnh hưởng fill data

### 16.1. Câu trả lời trực tiếp

> **KHÔNG có ảnh hưởng tiêu cực đến việc fill data trên form — VỚI ĐIỀU KIỆN thực hiện đủ 3 nhóm điều kiện dưới đây.**
> Ngược lại, phương án này **sửa được 3 lỗi fill data đang tồn tại**.

### 16.2. Ba điều kiện bắt buộc để KHÔNG mất dữ liệu

#### 🔴 ĐK-1 — Mọi binding và callback phải trỏ vào `context.EditModel` của đúng dòng

```razor
Value="@editModel.CustomerId"
ValueExpression="@(() => editModel.CustomerId)"
ValueChanged="@(async (Guid? v) => await Grid_SelectCustomer(editModel, v))"
```
```csharp
private async Task Grid_SelectCustomer(DistributorOfTeamDetailUpdateDto editModel, Guid? guid)
{
    if (editModel == null) return;
    editModel.CustomerId = guid;      // KHÔNG phải EditingDistributorOfTeamDetail
    ...
}
```

**Nếu vi phạm:** lỗi "chọn khách xong bị trắng" tái xuất hiện y hệt trước đây. Đây là điều kiện quan trọng nhất.

#### 🔴 ĐK-2 — Xóa sạch mọi gán `EditingDistributorOfTeamDetail` trong render tree và trong callback

Cụ thể phải xóa:
- `EditingDistributorOfTeamDetail = ((DistributorOfTeamDetailUpdateDto)context.EditModel);` tại [razor:265](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L265) (cột TÊN KHÁCH HÀNG)
- `EditingDistributorOfTeamDetail = ((DistributorOfTeamDetailUpdateDto)context.EditModel);` tại [razor:350](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor#L350) (cột TÊN ĐỘI BÁN HÀNG)
- `EditingDistributorOfTeamDetail = editModel;` — dòng bị sót trong `df7ccac29`
- `EditingDistributorOfTeamDetail.SalesTeamId = Guid.Empty;` tại [razor.cs:866](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L866) và [razor.cs:883](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs#L883)

**Nếu vi phạm:** render loop tiềm ẩn và ghi nhầm dòng khi grid re-render giữa lúc await. **Đây chính là điểm mà `df7ccac29` bỏ sót và dẫn tới revert.**

#### 🔴 ĐK-3 — Không dùng `DependsOn` và `EntityTypeForReload`

**Nếu vi phạm `DependsOn`:** component **tự động bắn `ValueChanged(null)`** khi phát hiện cascade đổi ([razor.cs:491-495](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs#L491-L495)) → **xóa `CustomerId` của dòng**. Đây là con đường mất dữ liệu trực tiếp nhất.

### 16.3. Ba lỗi fill data hiện có sẽ được SỬA

| # | Lỗi hiện tại | Nguyên nhân | Được sửa bởi |
|---|---|---|---|
| F1 | KH ngoài 1.000 → combobox trắng khi edit | `Data` chỉ có 1.000 dòng | `LoadSelectedItemAsync` → `GetComboboxByIdAsync` |
| F2 | `NullReferenceException` bị nuốt → `CustomerCode` giữ giá trị dòng trước (**dữ liệu sai âm thầm**) | `data.Code` không null-check + `catch {}` | `data?.Code` + `catch` tường minh |
| F3 | Xóa khách không clear `CustomerId`/`CustomerCode` | Thiếu nhánh `else` | Nhánh `else { editModel.CustomerCode = null; }` |

Cộng thêm sửa bug hiển thị: `TextFieldName` từ `Description` → `Code` cho cột "MÃ KHÁCH HÀNG".

### 16.4. Vì sao fill data khi MỞ chứng từ cũ chắc chắn không bị ảnh hưởng

Ba lớp bảo vệ **độc lập** với `CustomerCollection`:

1. **Cột hiển thị (`CellDisplayTemplate`)** đã dùng `HQSOFTCellDisplayTemplate` từ trước → server lookup + cache. **Không thay đổi gì.**
2. **Combobox khi edit** → `LoadSelectedItemAsync` → `GetComboboxByIdAsync` → resolve theo Id, **không lọc Status**, **không giới hạn 1.000**.
3. **`CustomerCode` lưu trong DB** → `DistributorOfTeamDetailUpdateDto.CustomerCode` là dữ liệu đã persist, load từ `GetListDataAsNoTrackingAsync`, **hoàn toàn không phụ thuộc combobox**.

→ Ngay cả khi cả 2 lớp trên hỏng, dữ liệu trong `CustomerId`/`CustomerCode` vẫn nguyên vẹn trong model và DB.

### 16.5. Rủi ro còn lại và cách phòng

| Rủi ro | Xác suất | Ảnh hưởng | Phòng ngừa |
|---|---|---|---|
| `TryGetPreservedValueWhenSpuriousClear` chặn nhầm thao tác xóa thật | Trung bình | Không xóa được khách | Test 15.7; fallback `ShowCustomClearButton="true"` |
| Latency mạng làm chậm hiển thị ô khi vào edit | Thấp | UX chậm ~200ms | Cache Mục 5.4 |
| Nhiều request khi grid có 50+ dòng lúc mở doc | Thấp | Tải server | `DisplayLoadGate(20,20)` đã chặn; preload Mục 9.5 |
| Sót một chỗ gán `EditingDistributorOfTeamDetail` | Trung bình | Lỗi trắng ô tái xuất | Grep `EditingDistributorOfTeamDetail\s*=` toàn file trước khi merge |

### 16.6. Lệnh kiểm tra cuối trước khi merge

```bash
# 1. Không còn CustomerCollection
grep -n "CustomerCollection" DistributorOfTeam.razor DistributorOfTeam.razor.cs
#    → phải KHÔNG có kết quả

# 2. Kiểm mọi phép gán vào biến global
grep -n "EditingDistributorOfTeamDetail\s*=" DistributorOfTeam.razor DistributorOfTeam.razor.cs
#    → CHỈ được còn: khởi tạo field (dòng 74), NewDataAsync,
#      OnFocusedRowChanged, EditModelSaving (reset về new())
#    → TUYỆT ĐỐI không được có trong CellEditTemplate hay trong Grid_Select*

# 3. Không dùng 2 property cấm
grep -n "DependsOn\|EntityTypeForReload" DistributorOfTeam.razor
#    → phải KHÔNG có kết quả

# 4. Không còn nạp 1.000 khách hàng
grep -n "GetListComboboxDataAsync" DistributorOfTeam.razor.cs
#    → phải KHÔNG có kết quả (chỉ được dùng GetListComboboxDataPagedAsync + GetComboboxByIdAsync)
```

### 16.7. Đánh giá tổng thể

| Tiêu chí | Đánh giá |
|---|---|
| **Rủi ro kỹ thuật** | **Thấp** — component + API đã production-proven ở SalesOrder, SalesRoute (in-grid), Depot (ngay trong chính file này) |
| **Phạm vi** | **Rất hẹp** — 2 file, ~80 dòng thay đổi ròng, 0 dòng backend |
| **Điểm rủi ro duy nhất** | Binding `editModel` — đã xác định chính xác nguyên nhân, có tiền lệ đúng để copy |
| **Lợi ích** | Tìm được toàn bộ KH trong DB (mục tiêu chính) + sửa 3 lỗi fill data + sửa bug hiển thị + giảm bộ nhớ 1.000 → ~200 DTO/circuit + tải trang nhanh hơn |
| **Khuyến nghị** | ✅ **NÊN triển khai**, theo đúng thứ tự Mục 13.3 và 3 điều kiện Mục 16.2 |

---

## Phụ lục A — Bảng tham chiếu file

| Vai trò | Đường dẫn |
|---|---|
| Trang cần sửa (markup) | [DistributorOfTeam.razor](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor) |
| Trang cần sửa (code-behind) | [DistributorOfTeam.razor.cs](src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs) |
| Mẫu tham chiếu — header form | [SalesOrder.razor:355-379](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor#L355-L379), [SalesOrder.razor.cs:12825-12865](src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs#L12825-L12865) |
| **Mẫu tham chiếu — TRONG GRID** ⭐ | [SalesRoute.razor:322-355](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor#L322-L355), [SalesRoute.razor.cs:1723-1745, 1819-1840](src/HQSOFT.Xspire.Application.Blazor/Pages/DMS/SalesRoute/SalesRoute.razor.cs#L1723-L1745) |
| Component (không sửa) | [HQSOFTComboBox.razor](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor), [.razor.cs](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/LazyCombobox/HQSOFTComboBox.razor.cs) |
| Helper (không sửa) | [ComboboxCustomDataHelper.cs](src/HQSOFT.Xspire.Application.Blazor/Commons/Helper/LazyCombobox/ComboboxCustomDataHelper.cs) |
| Cell display (không sửa) | [HQSOFTCellDisplayTemplate.razor](src/HQSOFT.Xspire.Application.Blazor/Commons/Components/HQSOFTCellDisplayTemplate.razor) |
| Contract (không sửa) | [ICustomersAppService.cs](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/Customers/ICustomersAppService.cs) |
| AppService (không sửa) | [CustomersAppService.cs:314-374](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/Customers/CustomersAppService.cs#L314-L374) |
| Repository (không sửa) | [EfCoreCustomerRepository.cs:301](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.cs#L301), [.Extended.cs:1171, 1184](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/Customers/EfCoreCustomerRepository.Extended.cs#L1171) |
| Hằng số paging | [ComboboxDataLimits.cs](modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application.Contracts/Shared/ComboboxDataLimits.cs) |
| Tài liệu framework | [HQSOFTComboBox.md](docs/_framework-docs/frontend/components/HQSOFTComboBox.md), [HQSOFTComboBox_Migration_Playbook.md](docs/_framework-docs/frontend/components/HQSOFTComboBox_Migration_Playbook.md), [HQSOFTComboBox_OnDemand_CustomData_Guide.md](docs/_framework-docs/frontend/components/HQSOFTComboBox_OnDemand_CustomData_Guide.md) |

## Phụ lục B — Lịch sử commit liên quan

| Commit | Thời gian | Nội dung | Đánh giá |
|---|---|---|---|
| `5045b3b46` | 2026-08-27 15:54 | Chuyển sang `HQSOFTComboBox` + server paging | ✅ Hướng đúng, thiếu guard/try-catch, sai `CellContext` |
| `df7ccac29` | 2026-08-27 17:22 | Truyền `editModel` vào `Grid_SelectCustomer` | ✅ Fix cốt lõi, **sót** `EditingDistributorOfTeamDetail = editModel` và các gán trong `CellEditTemplate` |
| `63b76acb1` | 2026-08-27 17:32 | Revert về `DxComboBox` + `CustomerCollection` | ⛔ Quay lại vấn đề ban đầu — chỉ 10 phút sau `df7ccac29` |

---

*Báo cáo lập ngày 2026-08-31. Không có file source nào bị thay đổi trong quá trình phân tích.*
