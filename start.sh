#!/bin/bash
# =============================================================================
# KỊCH BẢN TỰ ĐỘNG KHỞI ĐỘNG TOÀN BỘ HỆ THỐNG - ĐỀ TÀI 18 (DTC245200207)
# Dùng để khởi động lại web và các dịch vụ sau khi bật máy tính
# =============================================================================

# Di chuyển vào đúng thư mục dự án
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "====================================================================="
echo "   ĐANG KHỞI ĐỘNG HỆ THỐNG QUẢN LÝ HÓA ĐƠN (SMART BILLING SYSTEM)   "
echo "====================================================================="

# 1. Khởi chạy 10 container bằng Docker Compose
echo "[1/3] Đang khởi chạy toàn bộ 10 container..."
docker compose up -d

# 2. Chờ 3 giây để các container ổn định
echo "[2/3] Đang kiểm tra trạng thái dịch vụ..."
sleep 3

# 3. Hiển thị bảng trạng thái
echo "====================================================================="
echo "   TRẠNG THÁI CÁC DỊCH VỤ CONTAINER (DOCKER COMPOSE PS):            "
echo "====================================================================="
docker compose ps

# 4. In ra danh sách địa chỉ truy cập
IP="192.168.38.129"
echo ""
echo "====================================================================="
echo "   DANH SÁCH ĐỊA CHỈ TRUY CẬP (CLICK HOẶC COPY VÀO TRÌNH DUYỆT):     "
echo "====================================================================="
echo " 1. Web Quản lý Hóa đơn (HTTPS):  https://${IP}"
echo "    Web Quản lý Hóa đơn (HTTP):   http://${IP}"
echo " 2. Giám sát phần cứng cAdvisor:  http://${IP}:8088"
echo " 3. Giám sát Prometheus 4 Target: http://${IP}:9091/targets"
echo " 4. Bảng điều khiển Grafana:      http://${IP}:3001"
echo "    -> Tài khoản Grafana:         admin / AdminSecure2026!"
echo " 5. Quản trị CSDL pgAdmin 4:      http://${IP}:5050"
echo "    -> Tài khoản pgAdmin:         admin@billing.local / AdminSecure2026!"
echo "====================================================================="
echo ">>> HỆ THỐNG ĐÃ SẴN SÀNG 100%! BẠN CÓ THỂ MỞ TRÌNH DUYỆT ĐỂ THI! <<<"
