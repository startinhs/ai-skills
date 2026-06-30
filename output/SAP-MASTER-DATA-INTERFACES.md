# SAP Master Data Interfaces — API Reference

Module: `hqsoft.sap.dmsintegration`  
Controller: `SalesPersonController.Extended.cs`  
AppService: `ISalesPersonAppService.Extended.cs`

---

## Kiến trúc chung

Tất cả 5 interface master data đều đi qua **một SOAP service contract duy nhất**:

| Thông tin | Giá trị |
|-----------|---------|
| **SOAP URI** | `{baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx` |
| **REST Base URL** | `{baseUrl}/api/dms-integration/sales-person` |
| Protocol | SOAP 1.2 (SoapCore + XmlSerializer) |
| SOAP Namespace | `http://tempuri.org/` |
| Auth | `Username` + `Password` trong request body (anonymous, không cần Bearer) |

> **SOAP URI** được cấu hình qua `appsettings.json`:
> ```json
> "SOAPService": {
>   "ScopeType": "soap",
>   "Version": "v1",
>   "Vendor": "sap"
> }
> ```
> → URL pattern: `/ext/{ScopeType}/{Version}/{Vendor}/eSalesInterface.asmx`

Ngoài ra còn có endpoint SOAP phụ dành cho Employee:

| Service | URI |
|---------|-----|
> `ISalesPersonAppService` (IF_CUSTOMER, IF_DEPOT, IF_PRODUCT, IF_SALE_TEAM, IF_SALE_PERSON) | `/ext/soap/v1/sap/eSalesInterface.asmx` |
> `IEmployeeService` (legacy) | `/EmployeeService.asmx` |

### Response Format chung

```json
{
  "IsSuccess": true,
  "Message": "...",
  "ErrorMessage": "...",
  "Value": "..."
}
```

Base class: `BaseResponseOfString`

---

## IF_CUSTOMER — Secondary Customer

**URI:** `POST {baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx`  
**SOAP Action:** `http://tempuri.org/ImportSecondaryCustomer`

**Repository:** `ICustomerInterfacesRepository`

### Request

```
ImportSecondaryCustomer (kế thừa BaseRequest)
├── Username         : string
├── Password         : string
└── SecondaryCustomers : List<SecondaryCustomerDTO>
```

### SecondaryCustomerDTO (47 fields)

| Nhóm | Fields |
|------|--------|
| Core | CompanyCode, CustomerCode, SecondaryCustomerCode, SecondaryCustomerName, Address |
| Thông tin KH | BusinessType, Club, ContactName, Email, Phone, Phone2, TaxCode, VATRegistrationID |
| Phân loại | CustomerSegment, CustomerSegmentDescription, SecondaryCustomerClass, SecondaryCustomerGroup, SecondaryCustomerType |
| Thanh toán | PaymentMethod, PaymentTerm, PricePaymentTerm, CreditLimit |
| Phân cấp | ParentSecondaryCustomerCode, BudgetUnitCode |
| Địa chỉ giao hàng | ShipToAddress, ShipToPhone, BillToSecondaryCustomerCode |
| Thuộc tính mở rộng | Attribute1, Attribute2, Attribute3, Attribute4, Attribute5, Attribute6, Attribute7 |
| Nested | SecondaryCustomerShipToAddresses : List\<SecondaryCustomerShipToAddressDTO\> |

### Response

`ImportSecondaryCustomerResponse : BaseResponseOfString`

---

## IF_DEPOT — Location / Warehouse

**URI:** `POST {baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx`  
**SOAP Action:** `http://tempuri.org/ImportLocation`

**Repository:** `IDepotInterfacesRepository`

### Request

```
ImportLocationRequest (kế thừa BaseRequest)
├── Username      : string
├── Password      : string
└── Locations     : List<LocationDTO>
```

### LocationDTO (23 fields)

| Nhóm | Fields |
|------|--------|
| Core | CompanyCode, CustomerCode, LocationCode, LocationName, LocationType |
| Địa chỉ | Address, DefaultLogisticCode, OtherCity, OtherCityName |
| Logistics | Logistics (bool), Phone, Remark |
| Phân cấp bán hàng | SalesRegionL1, SalesRegionL1Name, SalesRegionL2, SalesRegionL2Name, SalesRegionL3, SalesRegionL3Name, SalesRegionL4, SalesRegionL4Name |
| Tuyến | SalesRouteCode |
| Trạng thái | Status, ChangeID |
| Nested | SalesRouteBins : List\<SalesRouteBinDTO\> |

### Response

`ImportLocationReponse : BaseResponseOfString`

---

## IF_PRODUCT — Product Master

**URI:** `POST {baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx`  
**SOAP Action:** `http://tempuri.org/ImportProduct`

**Repository:** `IProductInterfacesRepository`

### Request

```
ImportProductRequest (kế thừa BaseRequest)
├── Username   : string
├── Password   : string
└── Products   : List<ProductDTO>
```

### ProductDTO (27 fields)

| Nhóm | Fields |
|------|--------|
| Core | CompanyCode, ProductCode, ProductName, ProductName2, ProductName3, BaseUOMCode |
| Phân cấp | HierarchyL01, HierarchyL02, HierarchyL03, HierarchyL04, HierarchyL05 |
| Danh mục | CategoryL01, CategoryL02, CategoryL04, CategoryL05 |
| Giá / Thuế | ListPrice, StockBasePrice, TaxCode |
| Cờ | BOM (bool), PromotionProduct (bool) |
| Thuộc tính | Attribute01, Attribute02, Attribute03 |
| Metadata | ChangeID |
| Nested | ProductUOMs : List\<ProductUOMDTO\> |

### ProductUOMDTO (10 fields)

CompanyCode, ProductCode, UOMCode, QuantityBase, Quantity, UOMWeight, UOMNetWeight, Level, SellingUOM (bool), ChangeID

### Response

`ImportProductResponse : BaseResponseOfString`

---

## IF_SALE_PERSON — Employee / Nhân viên bán hàng

**URI (SOAP):** `POST {baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx`  
**SOAP Action:** `http://tempuri.org/ImportEmployee`  
**URI (REST):** `POST {baseUrl}/api/dms-integration/sales-person/ImportEmployee`

**Repository:** `ISalePersonRepository`

### Request

```
ImportEmployeeRequest (kế thừa BaseRequest)
├── Username    : string
├── Password    : string
└── Employees   : List<EmployeeDTO>
```

### EmployeeDTO (16 fields)

| Nhóm | Fields |
|------|--------|
| Core | CompanyCode, CustomerCode, EmployeeCode, EmployeeName, UserName |
| Hợp đồng | HiredDate, EndDate, JobTitle, Gender |
| Địa điểm | LocationCode, LocationName |
| Bán hàng | SalesRouteCode |
| Liên hệ | Phone |
| Metadata | Remark, Status, ChangeID |

### Response

`ImportEmployeeResponse : BaseResponseOfString`

---

## IF_SALE_TEAM — Sales Route / Sales Team

**URI:** `POST {baseUrl}/ext/soap/v1/sap/eSalesInterface.asmx`  
**SOAP Action:** `http://tempuri.org/ImportSalesRoute`

**Repository:** `ISalesTeamInterfacesRepository`

### Request

```
ImportSalesRouteRequest (kế thừa BaseRequest)
├── Username     : string
├── Password     : string
└── SalesRoutes  : List<SalesRouteDTO>
```

### SalesRouteDTO (10 fields)

| Field | Mô tả |
|-------|-------|
| CompanyCode | Mã công ty |
| CustomerCode | Mã khách hàng |
| SalesRouteCode | Mã tuyến bán hàng |
| SalesRouteName | Tên tuyến |
| SalesTeamCode | Mã team bán hàng |
| SaleTeamDescription | Mô tả team |
| Remark | Ghi chú |
| SalesRouteType | Loại tuyến |
| Status | Trạng thái |
| ChangeID | ID thay đổi |

### Response

`ImportSalesRouteReponse : BaseResponseOfString`

---

## File liên quan

| File | Đường dẫn |
|------|-----------|
| Controller | `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.HttpApi/Controllers/SalesPerson/SalesPersonController.Extended.cs` |
| AppService Interface | `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application.Contracts/SalesPerson/ISalesPersonAppService.Extended.cs` |
| Customer DTOs | `…Application.Contracts/Customers/CustomersDTO.cs` |
| Depot DTOs | `…Application.Contracts/Depots/DepotsDTO.cs` |
| Product DTOs | `…Application.Contracts/Products/ProductsDTO.cs` |
| Employee DTOs | `…Application.Contracts/Employee/EmployeeDTO.cs` |
| SalesTeam DTOs | `…Application.Contracts/SalesTeam/SalesTeamDTO.cs` |

---

*Ngày tạo: 2026-06-30*
