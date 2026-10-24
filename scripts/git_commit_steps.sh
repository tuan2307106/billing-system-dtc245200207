#!/bin/bash
# =============================================================================
# HƯỚNG DẪN VÀ THỰC HIỆN 03 COMMIT CHUẨN ĐÚNG THEO YÊU CẦU MÔN HỌC
# Học phần: Triển khai và Quản trị Hệ thống Phần mềm (TKQT HTPM K23)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "====================================================================="
echo "   THIẾT LẬP GIT REPOSITORY VÀ TẠO 03 COMMIT TIẾN ĐỘ THEO ĐỀ BÀI      "
echo "====================================================================="

# 1. Khởi tạo Git nếu chưa có
if [ ! -d .git ]; then
    git init
    git branch -M main
fi

# Đảm bảo file .env không bị thêm vào Git
git rm --cached .env 2>/dev/null || true

# -----------------------------------------------------------------------------
# CỘT MỐC 1 (COMMIT 1): Nginx Reverse Proxy + SSL tự ký + Security Headers
# -----------------------------------------------------------------------------
echo "==> Đang tạo Commit 1: Cấu hình Nginx Reverse Proxy, SSL và Security Headers..."
git add app/ postgres/ nginx/ .gitignore .env.example
git commit -m "feat(nginx): configure reverse proxy with self-signed SSL and security headers" || true

# -----------------------------------------------------------------------------
# CỘT MỐC 2 (COMMIT 2): Giám sát hệ thống với Prometheus, Grafana, cAdvisor
# -----------------------------------------------------------------------------
echo "==> Đang tạo Commit 2: Tích hợp Prometheus + Grafana giám sát container & CSDL..."
git add monitoring/
git commit -m "feat(monitoring): integrate prometheus and grafana for container and database metrics" || true

# -----------------------------------------------------------------------------
# CỘT MỐC 3 (COMMIT 3): Quản lý nhật ký tập trung với Loki + Promtail & LogQL
# -----------------------------------------------------------------------------
echo "==> Đang tạo Commit 3: Triển khai hệ thống log tập trung Loki + Promtail..."
git add logging/ docker-compose.yml scripts/ README.md docs/
git commit -m "feat(logging): setup loki and promtail centralized logging with logql queries" || true

echo "====================================================================="
echo "   LỊCH SỬ COMMIT TRÊN REPOSITORY HIỆN TẠI:                          "
echo "====================================================================="
git log --oneline -n 5

echo ""
echo "==> Để đẩy lên GitHub cá nhân của bạn, hãy chạy các lệnh sau:"
echo "    git remote add origin https://github.com/<TAI_KHOAN_GITHUB>/<TEN_REPO>.git"
echo "    git push -u origin main"
