# Hướng dẫn kiểm tra cấu hình SFTP đang dùng trên Production

## Mục đích

Tài liệu này dành cho người vận hành cần xác định backend trên môi trường khách hàng đang kết nối tới SFTP nào.

Các thông tin cần xác nhận:

| Trường | Ý nghĩa | Có thể ghi vào biên bản |
|---|---|---|
| `Host` | Tên miền hoặc IP máy chủ SFTP | Có |
| `Port` | Cổng kết nối, thường là `22` | Có |
| `Username` | Tài khoản kết nối | Chỉ ghi khi phạm vi chia sẻ cho phép |
| `Password` | Mật khẩu kết nối | Không chụp màn hình, không ghi vào biên bản |
| `InitialFolder` | Thư mục làm việc trên SFTP | Có |

## Điều quan trọng cần biết

Giá trị trong source chưa chắc là giá trị Production đang sử dụng. Backend nạp cấu hình theo thứ tự:

```text
appsettings.json
→ appsettings.Production.json
→ Environment variables của Docker/Azure
```

Cấu hình ở bước sau ghi đè cấu hình ở bước trước.

Ví dụ, trường JSON:

```json
{
  "SFTP": {
    "Host": "sftp.example",
    "Port": 22
  }
}
```

tương ứng với các Environment variables:

```text
SFTP__Host
SFTP__Port
SFTP__Username
SFTP__Password
SFTP__InitialFolder
```

Hai dấu gạch dưới `__` thay cho dấu `:` trong cấu hình .NET.

## Bước 1: Xác định môi trường

Trong Azure Portal, mở App Service của backend và vào **Environment variables**.

Tìm biến:

```text
ASPNETCORE_ENVIRONMENT
```

Nếu giá trị là `Production`, file môi trường được đọc là:

```text
appsettings.Production.json
```

Nếu biến không tồn tại hoặc có giá trị khác, cần ghi nhận đúng giá trị trước khi kiểm tra tiếp.

## Bước 2: Kiểm tra biến SFTP trên Azure

Tại **Environment variables → App settings**, tìm lần lượt:

```text
SFTP__Host
SFTP__Port
SFTP__Username
SFTP__Password
SFTP__InitialFolder
```

Không tìm từ khóa `appsetting`, vì Azure hiển thị từng biến cấu hình chứ không hiển thị file JSON thành một dòng.

Nếu một biến `SFTP__...` tồn tại trên Azure, giá trị đó ghi đè trường tương ứng trong file JSON.

Chỉ bấm **Show values** khi được cấp quyền xem bí mật. Không chụp, sao chép hoặc gửi giá trị `SFTP__Password` qua chat/email.

## Bước 3: Kiểm tra file trong container

Nếu App Service chạy custom Docker image:

1. Mở **SSH**.
2. Chọn **Application**, không chọn **Kudu**.
3. Chạy:

```bash
printenv ASPNETCORE_ENVIRONMENT
ls -la /app/appsettings.Production.json
```

**Kudu** là container công cụ chẩn đoán riêng của Azure. Khi terminal hiển thị `KuduLite` hoặc tài khoản dạng `kudu_ssh_user`, các lệnh đang chạy trong Kudu container, không phải container backend. Vì vậy đường dẫn `/app/appsettings.Production.json` có thể báo `No such file or directory`. Hãy quay lại menu **SSH → Application** rồi kiểm tra lại.

Chỉ hiển thị các trường không phải mật khẩu:

```bash
sed -n '/"SFTP"[[:space:]]*:/,/^[[:space:]]*}/p' /app/appsettings.Production.json \
  | grep -E '"(Host|Port|Username|InitialFolder)"'
```

Không dùng `cat /app/appsettings.Production.json` trong buổi chia sẻ màn hình vì file có thể chứa nhiều thông tin nhạy cảm khác.

Nếu App Service deploy code trực tiếp, không chạy custom Docker, kiểm tra tại:

```bash
ls -la /home/site/wwwroot/appsettings.Production.json
```

và xem riêng phần SFTP bằng:

```bash
sed -n '/"SFTP"[[:space:]]*:/,/^[[:space:]]*}/p' \
  /home/site/wwwroot/appsettings.Production.json \
  | grep -E '"(Host|Port|Username|InitialFolder)"'
```

## Bước 4: Kết luận giá trị đang có hiệu lực

Đối chiếu từng trường theo bảng sau:

| Trường | Giá trị trong file | Có Environment variable? | Giá trị ứng dụng dùng |
|---|---|---|---|
| `Host` | Ghi nhận | `SFTP__Host` | Environment variable nếu có, ngược lại dùng file |
| `Port` | Ghi nhận | `SFTP__Port` | Environment variable nếu có, ngược lại dùng file |
| `Username` | Ghi nhận hạn chế | `SFTP__Username` | Environment variable nếu có, ngược lại dùng file |
| `Password` | Không ghi giá trị | `SFTP__Password` | Environment variable nếu có, ngược lại dùng file |
| `InitialFolder` | Ghi nhận | `SFTP__InitialFolder` | Environment variable nếu có, ngược lại dùng file |

Mẫu kết quả bàn giao:

```text
Môi trường: Production
Nguồn cấu hình: appsettings.Production.json / Azure Environment variables
SFTP Host:
SFTP Port:
SFTP Username: [đã xác nhận, không công khai nếu nhạy cảm]
SFTP Password: [đã cấu hình, không ghi giá trị]
SFTP InitialFolder:
Người kiểm tra:
Thời điểm kiểm tra:
```

## Trường hợp deploy bằng GitLab vào Docker host

Pipeline hiện tại mount file từ Docker host vào container dưới dạng chỉ đọc:

```text
$API_VOLUME_PATH/appsettings.$ASPNETCORE_ENVIRONMENT.json
→ /app/appsettings.$ASPNETCORE_ENVIRONMENT.json
```

Với môi trường `Production`, file cần kiểm tra trên Docker host là:

```text
$API_VOLUME_PATH/appsettings.Production.json
```

Có thể xác nhận file đang được mount bằng:

```bash
docker inspect <ten-container-api> \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Sau đó kiểm tra các biến ghi đè mà không in giá trị bí mật:

```bash
docker inspect <ten-container-api> \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | sed 's/^\(SFTP__Password=\).*/\1[REDACTED]/' \
  | grep -E '^(ASPNETCORE_ENVIRONMENT|SFTP__)'
```

## Lưu ý bảo mật

- Không commit mật khẩu Production vào Git.
- Không đưa mật khẩu vào ticket, tài liệu bàn giao, ảnh chụp hoặc log.
- Ưu tiên lưu bí mật bằng Azure Key Vault hoặc secret setting được kiểm soát quyền truy cập.
- Sau khi xem bí mật để xử lý sự cố, không lưu lại trên máy cá nhân.
