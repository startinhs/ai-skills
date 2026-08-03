# Promotion Master `EP260600171` — Before/After

Nguồn đối chiếu:

- **Chưa sửa:** vùng SFA trong file `Compare_Promotion master_20260802153321-qa1-SAP800.xlsx`.
- **Đã sửa:** dữ liệu hiện tại trên PostgreSQL `avntt-du`, áp theo mapping của code exporter đã chỉnh.
- Chuỗi `""` biểu thị giá trị gửi đi là rỗng.

## 1. ZR74168 — PROMOTION DETAIL

Các cột liên quan:

- `E` — Promo. Detail Line ID
- `R` — Description
- `T` — Description Detail
- `U` — Promotion Bus Posting Group
- `W` — Sales Product Group Code

### Chưa sửa

| Promotion Code | E — Detail Line ID | R — Description | T — Description Detail | U — Bus Posting Group | W — Sales Product Group Code |
|---|---:|---|---|---|---|
| 0001 | 1 | AJI-NO-MOTO 230gL1,..n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0001 | 2 | BỘT NGỌT AJI-NO-MOTO 400gL19/L20/21...N | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0008 | 1 | AJI-NO-MOTO 230gL1,..n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0008 | 2 | AJI-NO-MOTO 400gR16/R17…n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0009 | 1 | AJI-NO-MOTO 230gL1,..n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0009 | 2 | BỘT NGỌT AJI-NO-MOTO 454gL14/19/20/21...N | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0013 | 1 | Giấm gạo 400ml3/4 | Mua 20 thùng Giấm gạo 4.9L tặng 1 thùng Giấm gạo 400ml | `""` | `""` |
| 0020 | 1 | Giấm gạo 400ml3/4 | Mua 10 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng 1 thùng Giấm gạo 400ml | `""` | `""` |
| 0021 | 1 | AJI-NO-MOTO 230gL1,..n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |
| 0021 | 2 | AJI-NO-MOTO 230gL1,..n | Mua 12 chai/1 thùng Giấm gạo 400ml and/or Giấm táo lên men 400ml tặng AJI-NO-MOTO | `""` | `""` |

### Đã sửa

| Promotion Code | E — Detail Line ID | R — Description (sản phẩm mua) | T — Description Detail | U — Bus Posting Group | W — Sales Product Group Code |
|---|---:|---|---|---|---|
| 0001 | 1 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0001 | 2 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0008 | 1 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0008 | 2 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0009 | 1 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0009 | 2 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0013 | 1 | Giấm gạo 4.9L8/L9... | `""` | PROMO | E01198 |
| 0020 | 1 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0021 | 1 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |
| 0021 | 2 | All item Giấm gạo 400ml and/or All item Giấm táo lên men 400ml | `""` | PROMO | E02241 |

## 2. PHÂN BỔ CHI PHÍ

Các cột liên quan:

- `D` — Promo. Detail Line ID
- `E` — Allocation Code
- `N` — Promotion Bus Posting Group

### Chưa sửa

| Promotion Code | D — Detail Line ID | E — Allocation Code | N — Bus Posting Group |
|---|---:|---:|---|
| 0001 | 35 | 61, 62, 63, 64 | PROMO |
| 0008 | 36 | 65, 66, 67, 68 | PROMO |
| 0009 | 37 | 69, 70, 71, 72 | PROMO |
| 0013 | 38 | 73, 74 | PROMO |
| 0020 | 39 | 75, 76 | PROMO |
| 0021 | 40 | 77, 78, 79, 80 | PROMO |

### Đã sửa

Mỗi detail có hai dòng phân bổ: Brand `407070` tỷ lệ `97%` và Brand `407072` tỷ lệ `3%`.

| Promotion Code | D — Detail Line ID | E — Allocation Code | N — Bus Posting Group |
|---|---:|---:|---|
| 0001 | 1 | 1, 2 | `""` |
| 0001 | 2 | 1, 2 | `""` |
| 0008 | 1 | 1, 2 | `""` |
| 0008 | 2 | 1, 2 | `""` |
| 0009 | 1 | 1, 2 | `""` |
| 0009 | 2 | 1, 2 | `""` |
| 0013 | 1 | 1, 2 | `""` |
| 0020 | 1 | 1, 2 | `""` |
| 0021 | 1 | 1, 2 | `""` |
| 0021 | 2 | 1, 2 | `""` |

## 3. STATUS

| Form | Đối tượng | Chưa sửa trong file SFA | Giá trị DB/code hiện tại |
|---|---|---|---|
| Header — cột J | EP260600171 | I | A |
| Promotion Line — cột R | 0001 | I | A |
| Promotion Line — cột R | 0008 | I | A |
| Promotion Line — cột R | 0009 | I | A |
| Promotion Line — cột R | 0013 | I | A |
| Promotion Line — cột R | 0020 | I | A |
| Promotion Line — cột R | 0021 | I | A |

## Kết quả mong đợi

- Promotion Detail lấy mô tả và mã nhóm từ **sản phẩm mua**, không lấy từ hàng tặng.
- Detail line dùng `Idx` liên tục giống UI (`1, 2, 3, ...`), không dùng index global của Promotion Program.
- Description Detail luôn rỗng.
- Promotion Detail Bus Posting Group luôn là `PROMO`.
- Budget Allocation Code reset từ `1` trong từng detail.
- Budget Allocation Bus Posting Group luôn rỗng.
- Status lấy trạng thái nghiệp vụ hiện tại là `A`.
