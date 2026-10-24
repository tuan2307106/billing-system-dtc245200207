#!/bin/bash
# =============================================================================
# SCRIPT CÀI ĐẶT MÔI TRƯỜNG DOCKER & DOCKER COMPOSE TRÊN UBUNTU 22.04 / 24.04
# Học phần: Triển khai và Quản trị Hệ thống Phần mềm (TKQT HTPM K23)
# =============================================================================

set -e

echo "====================================================================="
echo "   BẮT ĐẦU CÀI ĐẶT MÔI TRƯỜNG TRIỂN KHAI TRÊN MÁY ẢO UBUNTU LINUX    "
echo "====================================================================="

# 1. Cập nhật danh mục gói phần mềm
echo "==> [1/4] Đang cập nhật hệ thống apt..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git ufw

# 2. Thêm GPG key và kho lưu trữ chính thức của Docker
echo "==> [2/4] Đang thiết lập kho lưu trữ chính thức của Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

# 3. Cài đặt Docker CE, CLI, Containerd và Docker Compose Plugin
echo "==> [3/4] Cài đặt Docker Engine và Docker Compose Plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Cấu hình quyền chạy Docker cho người dùng hiện tại (không cần gõ sudo)
echo "==> [4/4] Cấu hình phân quyền nhóm docker cho user: $USER..."
sudo usermod -aG docker $USER || true

echo "====================================================================="
echo "   CÀI ĐẶT HOÀN TẤT! Vui lòng đăng xuất và đăng nhập lại hoặc chạy: "
echo "   newgrp docker"
echo "   Kiểm tra phiên bản bằng: docker --version && docker compose version"
echo "====================================================================="
