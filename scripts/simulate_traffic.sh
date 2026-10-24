#!/bin/bash
# =============================================================================
# SCRIPT TẠO LƯU LƯỢNG MẪU (SIMULATE TRAFFIC & LOGS)
# Địa chỉ IP máy ảo Ubuntu: 192.168.38.129
# =============================================================================

HOST="http://192.168.38.129"

echo "==> Bắt đầu gửi request mẫu đến Smart Billing System tại $HOST..."

for i in {1..20}; do
    echo -n "Request #$i: "
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/invoices"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/customers"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/services"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/reports"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/health"
    curl -s -o /dev/null -w "%{http_code}\n" "$HOST/metrics"
    sleep 0.5
done

echo "==> Đã tạo xong lưu lượng HTTP! Hãy mở Grafana Explore (http://192.168.38.129:3000) để xem metrics và truy vấn LogQL."
