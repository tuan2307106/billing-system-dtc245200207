# 🏢 Smart Billing & Invoicing System (Hệ thống Quản lý Hóa đơn & Doanh thu)

> **Học phần:** Triển khai và Quản trị Hệ thống Phần mềm (TKQT HTPM K23)  
> **Đề tài số 18:** Hệ thống Quản lý Hóa đơn / Billing  
> **Địa chỉ IP máy ảo Ubuntu:** `192.168.38.129`  
> **Công nghệ:** Python (Flask), PostgreSQL 16, pgAdmin 4, Nginx Reverse Proxy, Prometheus, Grafana, Loki, Promtail, cAdvisor, Docker Compose.

---

## 📌 1. Giới thiệu Đề tài

Hệ thống Quản lý Hóa đơn (**Smart Billing System**) là giải pháp phần mềm quản trị hóa đơn điện tử, bán cước dịch vụ công nghệ thông tin (Cloud, Database, Bảo trì, Bản quyền bảo mật), theo dõi trạng thái thanh toán và phân tích doanh thu. Toàn bộ hệ sinh thái dịch vụ được đóng gói bằng **Docker Compose**, phân tách mạng an toàn (**Network Isolation**), áp dụng đầy đủ các kỹ thuật bảo mật nâng cao (**Hardening**) và giám sát vận hành thời gian thực trên môi trường máy ảo Ubuntu tại địa chỉ IP `192.168.38.129`.

---

## 🏛️ 2. Sơ đồ Kiến trúc Hệ thống (System Architecture)

```
                            [ NGƯỜI DÙNG / CLIENT ]
                                      │
                 ┌────────────────────┴────────────────────┐
                 │ HTTP (Port 80)           HTTPS (Port 443)│
                 ▼                                         ▼
         ┌─────────────────────────────────────────────────────────┐
         │         pos-nginx / billing-nginx (Reverse Proxy)       │
         │           • Cấu hình IP máy ảo: 192.168.38.129          │
         │           • SSL/TLS Termination (Tự ký OpenSSL)        │
         │           • Security Headers (X-Frame, nosniff...)     │
         └────────────────────────────┬────────────────────────────┘
                                      │ (frontend-net)
                                      ▼
         ┌─────────────────────────────────────────────────────────┐
         │             billing-web:5000 (Flask / Gunicorn)         │
         │               • Non-Root User (UID 1001)                │
         │               • Endpoint /metrics (Prometheus Scraper)  │
         │               • Endpoint /health (Healthcheck)          │
         └────────────────────────────┬────────────────────────────┘
                                      │ (backend-net cô lập: internal: true)
                                      ▼
         ┌─────────────────────────────────────────────────────────┐
         │               billing-db:5432 (PostgreSQL 16)           │
         │        • Cấm công khai port 5432 ra bên ngoài host     │
         │        • Kết nối nội bộ với web app & postgres_exporter │
         └─────────────────────────────────────────────────────────┘
                                      ▲
                                      │ (Quản trị CSDL qua giao diện web)
                     [ billing-pgadmin:5050 (Port 5050:80) ]

───────────────────────────────────────────────────────────────────────────
                  HẠ TẦNG GIÁM SÁT & LOG TẬP TRUNG (monitor-net)
───────────────────────────────────────────────────────────────────────────
   [ billing-cadvisor ] ────┐
   [ billing-web:5000 ] ────┼──► [ billing-prometheus:9090 ] ──┐
   [ postgres-exporter] ────┘                                  │
                                                               ├──► [ billing-grafana:3000 ]
   [ Containers Log ]  ────► [ billing-promtail ] ──► [ billing-loki:3100 ] ┘
```

---

## 🔌 3. Danh sách Cổng Dịch vụ & Địa chỉ Truy cập (IP: 192.168.38.129)

| Tên Dịch vụ Container | Image Docker | Cổng Host | URL Truy cập (IP Ubuntu) | Vai trò & Mục đích |
| :--- | :--- | :--- | :--- | :--- |
| **billing-nginx (HTTP)** | `nginx:1.25-alpine` | `80` | `http://192.168.38.129` | Tiếp nhận và điều hướng lưu lượng HTTP |
| **billing-nginx (HTTPS)**| `nginx:1.25-alpine` | `443` | `https://192.168.38.129` | Cổng bảo mật SSL tự ký & Security Headers |
| **billing-web** | Tự build từ `./app` | Nội bộ (`5000`) | Qua Reverse Proxy | Ứng dụng Quản lý Hóa đơn, Non-Root UID 1001 |
| **billing-db** | `postgres:16-alpine` | Không mở cổng | Nội bộ `backend-net` | CSDL PostgreSQL 16 (Bảo mật: cấm mở 5432) |
| **billing-pgadmin** | `dpage/pgadmin4` | `5050` | `http://192.168.38.129:5050` | Quản trị CSDL PostgreSQL trực quan |
| **billing-prometheus**| `prom/prometheus:v2.45.0` | `9090` | `http://192.168.38.129:9090` | Thu thập chỉ số hiệu năng định kỳ |
| **billing-grafana** | `grafana/grafana:10.0.3` | `3000` | `http://192.168.38.129:3000` | Dashboard giám sát trực quan & LogQL |
| **billing-cadvisor** | `gcr.io/cadvisor/cadvisor`| `8088` | `http://192.168.38.129:8088` | Giám sát tài nguyên CPU/RAM container |
| **billing-postgres-exporter** | `prometheuscommunity/postgres-exporter` | Nội bộ (`9187`) | Nội bộ `monitor-net` | Thu thập số liệu kết nối PostgreSQL |
| **billing-loki** | `grafana/loki:2.8.4` | `3100` | `http://192.168.38.129:3100` | Lưu trữ nhật ký tập trung của toàn hệ thống |
| **billing-promtail** | `grafana/promtail:2.8.4` | Không mở cổng | Nội bộ `monitor-net` | Đọc log file Docker và đẩy về Loki |

---

## 🚀 4. Hướng dẫn Cài đặt & Triển khai trên Máy ảo Ubuntu Linux (192.168.38.129)

### Bước 1: Chuẩn bị môi trường Docker trên Ubuntu
```bash
# Cập nhật danh mục gói phần mềm
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y git curl

# Phân quyền thực thi và chạy script cài đặt môi trường
chmod +x scripts/setup_ubuntu.sh
./scripts/setup_ubuntu.sh

# Cập nhật quyền chạy Docker cho user hiện tại (không cần gõ sudo)
newgrp docker
```

### Bước 2: Thiết lập biến môi trường và chứng chỉ SSL cho IP 192.168.38.129
```bash
cd ~/billing-system
cp .env.example .env

# Khởi tạo chứng chỉ SSL tự ký có Subject Alternative Name (SAN) cho IP 192.168.38.129
bash nginx/ssl/generate_ssl.sh
```

### Bước 3: Khởi chạy toàn bộ hệ thống bằng Docker Compose
```bash
# Build và chạy 10 container ngầm (-d)
docker compose up -d --build

# Kiểm tra trạng thái hoạt động của các container
docker compose ps
```

---

## 🌐 5. Kiểm tra & Truy cập Hệ thống từ Máy Host hoặc Trình duyệt

Từ trình duyệt máy thật (Windows) hoặc máy ảo Ubuntu, truy cập:

1. **Website Hóa đơn (HTTP):** `http://192.168.38.129`
2. **Website Hóa đơn (HTTPS):** `https://192.168.38.129` *(Bấm "Advanced" -> "Proceed to 192.168.38.129" để chấp nhận chứng chỉ tự ký)*
3. **Quản trị CSDL pgAdmin 4:** `http://192.168.38.129:5050`
   - **Tài khoản:** `admin@billing.local`
   - **Mật khẩu:** `AdminSecure2026!`
   - *Thông số kết nối DB trong pgAdmin:* Host: `billing-db`, Port: `5432`, DB: `billing_db`, User: `billing_user`, Password: `BillingSecure2026!Pass`.
4. **Hệ thống Giám sát Prometheus:** `http://192.168.38.129:9090`
5. **Bảng điều khiển Grafana Dashboard:** `http://192.168.38.129:3000`
   - **Tài khoản:** `admin`
   - **Mật khẩu:** `AdminSecure2026!`
   - *Dashboard đã được nạp tự động (Provisioning) tại thư mục `Billing System`*.
6. **Kiểm tra Security Headers từ Terminal:**
```bash
curl -k -sSI https://192.168.38.129 | grep -Ei 'HTTP/|Server|X-Frame|X-Content|Referrer'
```

---

## 🔍 6. Truy vấn Nhật ký bằng LogQL (Loki + Promtail)

Mở Grafana tại mục **Explore** (`http://192.168.38.129:3000/explore`), chọn Data source là **Loki** và thực thi ít nhất 3 truy vấn sau:

### Query 1: Lấy toàn bộ nhật ký ghi nhận của các container
```logql
{job="docker"}
```

### Query 2: Lọc các yêu cầu thu thập dữ liệu chỉ số `/metrics` từ Prometheus
```logql
{job="docker"} |= "/metrics"
```

### Query 3: Tra cứu các hành vi tạo hóa đơn mới trong ứng dụng
```logql
{job="docker"} |= "CREATE_INVOICE"
```

### Query 4: Tra cứu lỗi hệ thống hoặc HTTP status 4xx, 5xx
```logql
{job="docker"} |~ "(ERROR|error|500|404)"
```

---

## 🛡️ 7. Các Biện pháp Hardening Bảo mật Đã Áp Dụng

1. **Non-Root Container:** Container ứng dụng `billing-web` được cấu hình người dùng thông thường `appuser` (UID 1001) trong `Dockerfile`, ngăn chặn leo thang đặc quyền Kernel.
2. **Docker Network Isolation:** Phân chia thành 3 mạng độc lập (`frontend-net`, `backend-net`, `monitor-net`). Trong đó `backend-net` có thuộc tính `internal: true`, ngăn chặn tuyệt đối truy cập từ máy chủ host và bên ngoài tới cổng 5432 của PostgreSQL.
3. **HTTP Security Headers:** Nginx được thiết lập cấu hình chặn clickjacking (`X-Frame-Options: SAMEORIGIN`), chống sniffing MIME (`X-Content-Type-Options: nosniff`), chống tấn công XSS (`X-XSS-Protection`), quy định chính sách bảo mật nội dung (`Content-Security-Policy`) và ẩn phiên bản Nginx (`server_tokens off`).
4. **Quản lý Thông tin Nhạy cảm:** Tách biệt biến môi trường vào `.env`, sử dụng `.gitignore` để ngăn chặn lộ mật khẩu cơ sở dữ liệu lên GitHub. Cung cấp file `.env.example` an toàn.
5. **Giới hạn Tài nguyên (Resource Limits):** Mọi dịch vụ trong `docker-compose.yml` đều được giới hạn CPU (`cpus`) và bộ nhớ (`memory`), giảm thiểu nguy cơ tấn công từ chối dịch vụ (DoS).

---

## 📦 8. Hướng dẫn Đẩy Dự án lên GitHub với 03 Commit Quy Định

Học phần yêu cầu tối thiểu **03 commits** có nội dung rõ ràng, phản ánh các cột mốc thực hiện:

### Bước 1: Khởi tạo Git và cấu hình thông tin cá nhân
```bash
git init
git branch -M main
git config user.name "Họ và Tên Sinh Viên"
git config user.email "email_sinhvien@gmail.com"
```

### Bước 2: Thực hiện Commit 1 (Cột mốc Bước 3)
```bash
git add app/ postgres/ nginx/ .gitignore .env.example
git commit -m "feat(nginx): configure reverse proxy with self-signed SSL and security headers"
```

### Bước 3: Thực hiện Commit 2 (Cột mốc Bước 4)
```bash
git add monitoring/
git commit -m "feat(monitoring): integrate prometheus and grafana for container and database metrics"
```

### Bước 4: Thực hiện Commit 3 (Cột mốc Bước 5 & Hoàn thiện)
```bash
git add logging/ docker-compose.yml scripts/ README.md docs/
git commit -m "feat(logging): setup loki and promtail centralized logging with logql queries"
```

### Bước 5: Đẩy mã nguồn lên GitHub cá nhân
Tạo một Repository mới trên GitHub đặt tên theo Mã số sinh viên (ví dụ: `billing-system-dtc245200xxx`), sau đó liên kết và đẩy code:
```bash
git remote add origin https://github.com/<TAI_KHOAN_GITHUB>/billing-system-dtc245200xxx.git
git push -u origin main
```

---

*Chúc các bạn hoàn thành xuất sắc Bài tập lớn môn Triển khai và Quản trị Hệ thống Phần mềm!*
