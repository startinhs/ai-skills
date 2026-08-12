# Review: SAP BudgetAllocation theo dòng Chi tiết khuyến mãi

## Kết luận

Implementation hiện tại **đúng với yêu cầu đã mô tả**:

- Mỗi dòng `#` tại khu vực `OM.PP.PromotionDetail` sinh một thẻ `<BUDGET_ALLOC>` tương ứng.
- `PromotionDetailLineID` lấy từ `PromotionBreak.Idx`, chính là giá trị cột `#` trên màn hình.
- Mỗi Budget Allocation được lặp lại cho toàn bộ dòng Promotion Detail.
- `AllocationCode` vẫn lấy từ `PromotionBudgetAllocation.Idx` và không bị thay đổi khi nhân bản.

Công thức số thẻ xuất ra:

```text
Số thẻ BUDGET_ALLOC
= Số dòng PromotionBreak đang hiệu lực
× Số dòng PromotionBudgetAllocation đang hiệu lực
```

## Branch và file thay đổi

- Branch: `fix/sap-budget-allocation-by-promotion-detail`
- Base branch: `release/1.0.0-avntt-rc1`
- File sửa:
  `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/PromotionMaster/EfCorePromotionMasterRepository.Extended.cs`
- Phương thức: `createBudgetAllocation(...)`
- Trạng thái: thay đổi chưa commit.

## Nguồn dữ liệu

| Dữ liệu SAP             | Nguồn dữ liệu Xspire           |
| ------------------------- | --------------------------------- |
| `PromotionDetailLineID` | `PromotionBreak.Idx`            |
| `AllocationCode`        | `PromotionBudgetAllocation.Idx` |
| `PromotionCode`         | `PromotionProgram.Code`         |
| `PromotionMasterCode`   | `PromotionProgramHeader.Code`   |

Grid `OM.PP.PromotionDetail` bind cột `#` bằng:

```razor
<DxGridDataColumn FieldName="Idx"
                  Width="60px"
                  Caption="#">
```

Entity tương ứng:

```csharp
public virtual int Idx { get; set; }
```

trong entity `PromotionBreak`.

## Logic trước khi sửa

Code cũ cố chia danh sách Budget Allocation thành các nhóm dựa trên số dòng Promotion Detail:

```csharp
var allocationsPerDetail = breakIndexes.Count > 0
                           && budgetList.Count % breakIndexes.Count == 0
    ? budgetList.Count / breakIndexes.Count
    : 0;
```

Sau đó mỗi Budget Allocation chỉ tạo **một** thẻ SAP. Vì vậy, trường hợp có:

- 2 dòng Promotion Detail (`#1`, `#2`)
- 1 dòng Budget Allocation

thì `1 % 2 != 0`, code không thể ghép allocation với từng detail và chỉ xuất một thẻ theo giá trị fallback. Kết quả không đáp ứng yêu cầu nhân bản thành hai thẻ.

## Logic sau khi sửa

Lấy danh sách `PromotionBreak.Idx` đang hiệu lực:

```csharp
var breakIndexes = await breakQuery
    .OrderBy(x => x.Idx)
    .Select(x => x.Idx)
    .ToListAsync();
```

Chuyển thành danh sách `PromotionDetailLineID`:

```csharp
var detailLineIds = breakIndexes.Count > 0
    ? breakIndexes.Select(GetSapPromotionDetailLineId)
    : new[] { program.Idx.ToString() };
```

Sau đó nhân từng dòng Promotion Detail với từng Budget Allocation:

```csharp
foreach (var detailLineId in detailLineIds)
{
    foreach (var budget in budgetList)
    {
        listData.Add(new BudgetAllocDomain
        {
            PromotionDetailLineID = detailLineId,
            AllocationCode = budget.Idx.ToString(),
            // Các trường Budget Allocation khác giữ nguyên.
        });
    }
}
```

Đây là phép nhân hai tập dữ liệu, bảo đảm không bỏ sót dòng Promotion Detail.

## Ví dụ cần đáp ứng

### Dữ liệu màn hình

`OM.PP.PromotionDetail` có hai dòng:

| # | Nguồn DB                  |
| -: | -------------------------- |
| 1 | `PromotionBreak.Idx = 1` |
| 2 | `PromotionBreak.Idx = 2` |

Có một dòng Budget Allocation:

```text
PromotionBudgetAllocation.Idx = 1
BrandCode = 404043
AllocationPercent = 100.0000000
```

### Kết quả SAP mong đợi

Thẻ thứ nhất:

```xml
<BUDGET_ALLOC>
  <CompanyCode>AVN</CompanyCode>
  <PromotionCode>0185</PromotionCode>
  <PromotionMasterCode>EP260600255</PromotionMasterCode>
  <PromotionDetailLineID>1</PromotionDetailLineID>
  <AllocationCode>1</AllocationCode>
  <BrandCode>404043</BrandCode>
  <BrandName>Aji-ngon Vegetarian</BrandName>
  <SectionCode>42105</SectionCode>
  <SectionName>Tradition Trade Sales</SectionName>
  <ExpenseCode>6321999999</ExpenseCode>
  <ExpenseName>COGS_PROMOTION BY PRODUCT</ExpenseName>
  <AllocationPercent>100.0000000</AllocationPercent>
  <PANo />
  <ProBusPostingGroup />
  <ProductCode />
  <Deleted>false</Deleted>
</BUDGET_ALLOC>
```

Thẻ thứ hai giữ nguyên thông tin allocation, chỉ đổi dòng chi tiết:

```xml
<BUDGET_ALLOC>
  <CompanyCode>AVN</CompanyCode>
  <PromotionCode>0185</PromotionCode>
  <PromotionMasterCode>EP260600255</PromotionMasterCode>
  <PromotionDetailLineID>2</PromotionDetailLineID>
  <AllocationCode>1</AllocationCode>
  <BrandCode>404043</BrandCode>
  <BrandName>Aji-ngon Vegetarian</BrandName>
  <SectionCode>42105</SectionCode>
  <SectionName>Tradition Trade Sales</SectionName>
  <ExpenseCode>6321999999</ExpenseCode>
  <ExpenseName>COGS_PROMOTION BY PRODUCT</ExpenseName>
  <AllocationPercent>100.0000000</AllocationPercent>
  <PANo />
  <ProBusPostingGroup />
  <ProductCode />
  <Deleted>false</Deleted>
</BUDGET_ALLOC>
```

## Ma trận kiểm tra

| Promotion Detail | Budget Allocation | Số thẻ SAP | Kết quả`PromotionDetailLineID`    |
| ---------------: | ----------------: | -----------: | ------------------------------------- |
|                2 |                 1 |            2 | `1`, `2`                          |
|                2 |                 2 |            4 | Mỗi allocation có ID`1`, `2`    |
|                3 |                 1 |            3 | `1`, `2`, `3`                   |
|                0 |                 1 |            1 | Fallback sang`PromotionProgram.Idx` |
|                2 |                 0 |            0 | Không có allocation để xuất      |

## Phạm vi soft delete

Ở luồng xuất thông thường (`actionID != Delete`):

- Chỉ lấy `PromotionBreak` có `IsDeleted = false`.
- Chỉ lấy `PromotionBudgetAllocation` có `IsDeleted = false`.

Do đó số thẻ được tính theo các dòng đang hiệu lực, phù hợp với dữ liệu đang hiển thị trên màn hình.

Riêng action xóa Budget Allocation (`DB`):

- Chỉ lấy `PromotionBudgetAllocation` có `IsDeleted = true`.
- Vẫn lấy các dòng `PromotionBreak` đang hiệu lực.
- Mỗi allocation đã soft-delete được nhân theo từng `PromotionBreak.Idx`.
- Các thẻ xuất ra có `<Deleted>true</Deleted>`.

Logic lọc:

```csharp
if (actionID == ConstantsData.DeleteBudgetAllocation)
{
    budgetQuery = budgetQuery.Where(x => x.IsDeleted);
}
else if (actionID != ConstantsData.Delete)
{
    budgetQuery = budgetQuery.Where(x => !x.IsDeleted);
}
```

## Kết quả kỹ thuật

- `git diff --check`: đạt.
- Build project SAP EntityFrameworkCore với `--no-dependencies`: thành công, **0 errors**.
- Build toàn cây dependency ban đầu bị môi trường chặn ghi package vào `C:\Working\Packages`; đây không phải lỗi code.
- Build có warning sẵn có về package vulnerability, nullable và DevExpress license; không có error phát sinh từ thay đổi này.

## Điểm cần xác nhận nghiệp vụ

Implementation dùng **giá trị thực tế của cột `#`** (`PromotionBreak.Idx`), không tự tạo lại dãy `1..n` tại lúc export. Với dữ liệu chuẩn, UI đã lưu `Idx` liên tục nên kết quả là `1, 2, 3, ...`.

Nếu nghiệp vụ muốn luôn đánh lại số liên tục khi export, kể cả DB có `Idx` bị hổng như `1, 3`, cần một yêu cầu khác. Theo trao đổi hiện tại, lấy đúng giá trị cột `#` là phù hợp.
