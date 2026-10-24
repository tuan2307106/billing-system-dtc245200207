# =============================================================================
# DOCKERFILE - SMART BILLING WEB APPLICATION (PYTHON / FLASK)
# Hardening: Chạy với Non-Root User (UID 1001: appuser)
# =============================================================================

FROM python:3.11-slim-bookworm

# Thiết lập biến môi trường
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000 \
    APP_HOME=/app

# Cài đặt các gói thư viện hệ thống cần thiết (curl phục vụ healthcheck, libpq cho postgresql)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Tạo người dùng Non-Root để tăng cường bảo mật (Hardening)
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/bash -m appuser

# Thiết lập thư mục làm việc
WORKDIR $APP_HOME

# Sao chép và cài đặt các phụ thuộc Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Sao chép toàn bộ mã nguồn ứng dụng
COPY . .

# Phân quyền thư mục cho người dùng non-root
RUN chown -R appuser:appgroup $APP_HOME

# Chuyển sang người dùng Non-Root (UID 1001)
USER 1001

# Khai báo cổng ứng dụng
EXPOSE 5000

# Kiểm tra sức khỏe container (Container Healthcheck)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Khởi chạy ứng dụng bằng Gunicorn WSGI Server chất lượng sản xuất
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "3", "--access-logfile", "-", "--error-logfile", "-", "main:app"]
