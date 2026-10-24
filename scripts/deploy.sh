#!/bin/bash
# =============================================================================
# SCRIPT KHỞI CHẠY VÀ KIỂM TRA HỆ THỐNG SMART BILLING SYSTEM
# Địa chỉ IP máy ảo Ubuntu: 192.168.38.129
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
VM_IP="192.168.38.129"

echo "====================================================================="
echo "   TRIỂN KHAI TOÀN DIỆN SMART BILLING SYSTEM TRÊN UBUNTU: $VM_IP   "
echo "====================================================================="

# 1. Kiểm tra file .env
if [ ! -f .env ]; then
    echo "==> Chưa có file .env, tự động sao chép từ .env.example..."
    cp .env.example .env
fi

# 2. Kiểm tra chứng chỉ SSL Nginx cho IP máy ảo
if [ ! -f nginx/ssl/server.crt ] || [ ! -f nginx/ssl/server.key ]; then
    echo "==> Đang khởi tạo chứng chỉ SSL cho Nginx (IP: $VM_IP)..."
    bash nginx/ssl/generate_ssl.sh
fi

# 3. Build và khởi chạy Docker Compose
echo "==> Đang đóng gói và khởi chạy 10 container dịch vụ..."
docker compose up -d --build

# 4. Chờ cơ sở dữ liệu sẵn sàng
echo "==> Đang chờ cơ sở dữ liệu PostgreSQL khởi động..."
sleep 5

# 5. Kiểm tra danh sách container
echo "====================================================================="
echo "   TRẠNG THÁI CÁC DỊCH VỤ CONTAINER ĐANG HOẠT ĐỘNG:                 "
echo "====================================================================="
docker compose ps

echo ""
echo "====================================================================="
echo "   HỆ THỐNG ĐÃ KHỞI CHẠY THÀNH CÔNG! ĐỊA CHỈ TRUY CẬP (IP: $VM_IP)   "
echo "====================================================================="
echo "   1. Website Quản lý Hóa đơn (HTTP)  : http://$VM_IP"
echo "   2. Website Quản lý Hóa đơn (HTTPS) : https://$VM_IP (Bỏ qua cảnh báo SSL)"
echo "   3. Quản trị PostgreSQL (pgAdmin 4) : http://$VM_IP:5050"
echo "      - Email   : admin@billing.local"
echo "      - Mật khẩu: AdminSecure2026!"
echo "   4. Giám sát Prometheus             : http://$VM_IP:9090"
echo "   5. Giám sát Dashboard Grafana      : http://$VM_IP:3000"
echo "      - User    : admin"
echo "      - Mật khẩu: AdminSecure2026!"
echo "   6. Giám sát Container (cAdvisor)   : http://$VM_IP:8088"
echo "   7. Nhật ký tập trung (Loki)        : http://$VM_IP:3100"
echo "====================================================================="
