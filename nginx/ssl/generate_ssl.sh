#!/bin/bash
# =============================================================================
# TỰ ĐỘNG TẠO CHỨNG CHỈ SSL TỰ KÝ CHO NGINX REVERSE PROXY
# Địa chỉ IP máy ảo Ubuntu: 192.168.38.129
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR"
VM_IP="192.168.38.129"

echo "==> Đang khởi tạo chứng chỉ SSL tự ký cho Smart Billing System (IP: $VM_IP)..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/server.key" \
    -out "$SSL_DIR/server.crt" \
    -subj "/C=VN/ST=ThaiNguyen/L=ThaiNguyen/O=ICTU/OU=TKQT_HTPM/CN=$VM_IP" \
    -addext "subjectAltName=IP:$VM_IP,IP:127.0.0.1,DNS:billing.local,DNS:localhost"

chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"

echo "==> Tạo chứng chỉ SSL thành công cho $VM_IP tại: $SSL_DIR"
ls -la "$SSL_DIR"
