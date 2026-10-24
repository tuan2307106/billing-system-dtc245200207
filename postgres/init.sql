-- =============================================================================
-- HỆ THỐNG QUẢN LÝ HÓA ĐƠN & THANH TOÁN (SMART BILLING & INVOICING SYSTEM)
-- Môn học: Triển khai và Quản trị Hệ thống Phần mềm (TKQT HTPM K23)
-- Đề tài số 18: Hệ thống Quản lý Hóa đơn / Billing
-- Cơ sở dữ liệu: PostgreSQL 16
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. BẢNG KHÁCH HÀNG (CUSTOMERS)
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    customer_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    tax_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. BẢNG DỊCH VỤ / MẶT HÀNG (SERVICES & PRODUCTS)
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT 'Cloud & IT Services',
    description TEXT,
    unit_price NUMERIC(15, 2) NOT NULL,
    unit VARCHAR(30) DEFAULT 'Tháng',
    tax_rate NUMERIC(5, 2) DEFAULT 10.00, -- Thuế suất VAT (%)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. BẢNG HÓA ĐƠN (INVOICES)
CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    subtotal NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    tax_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('DRAFT', 'PENDING', 'PAID', 'OVERDUE', 'CANCELLED')),
    payment_method VARCHAR(50) DEFAULT 'Bank Transfer',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. BẢNG CHI TIẾT HÓA ĐƠN (INVOICE ITEMS)
CREATE TABLE IF NOT EXISTS invoice_items (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    service_id INTEGER REFERENCES services(id) ON DELETE SET NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    unit_price NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    tax_rate NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00
);

-- 5. BẢNG THANH TOÁN (PAYMENTS)
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    amount NUMERIC(15, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'Bank Transfer',
    transaction_ref VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. BẢNG NHẬT KÝ KIỂM TOÁN HỆ THỐNG (AUDIT LOGS)
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER,
    details TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- TẠO CHỈ MỤC TĂNG TỐC TRUY VẤN
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(issue_date);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);

-- DỮ LIỆU KHỞI TẠO MẪU (SEED DATA)
INSERT INTO customers (customer_code, name, company, email, phone, address, tax_id) VALUES
('KH-001', 'Nguyễn Văn An', 'Tập đoàn Công nghệ FPT', 'an.nguyen@fpt.com.vn', '0912345678', 'Tòa nhà FPT, Phố Duy Tân, Cầu Giấy, Hà Nội', '0101234567'),
('KH-002', 'Trần Thị Bích', 'Tổng Công ty Viễn thông Viettel', 'bich.tran@viettel.vn', '0987654321', 'Số 1 Giang Văn Minh, Ba Đình, Hà Nội', '0102345678'),
('KH-003', 'Lê Hoàng Nam', 'Công ty Cổ phần VNG', 'nam.le@vng.com.vn', '0903112233', 'Khu chế xuất Tân Thuận, Quận 7, TP.HCM', '0303456789'),
('KH-004', 'Phạm Minh Đức', 'Công ty CP Giải pháp VinFast', 'duc.pham@vinfast.vn', '0945678901', 'Khu đô thị Vinhomes Riverside, Long Biên, Hà Nội', '0104567890'),
('KH-005', 'Vũ Hải Yến', 'Công ty TNHH MoMo Fintech', 'yen.vu@momo.vn', '0978998877', 'Tòa nhà Phú Mỹ Hưng, Quận 7, TP.HCM', '0305678901')
ON CONFLICT (customer_code) DO NOTHING;

INSERT INTO services (code, name, category, description, unit_price, unit, tax_rate) VALUES
('SRV-CLOUD-01', 'Dịch vụ Dedicated Cloud Server (16 vCPU, 64GB RAM)', 'Cloud Infrastructure', 'Máy chủ đám mây hiệu năng cao lưu trữ hệ thống ERP & Billing', 12500000.00, 'Tháng', 10.00),
('SRV-DB-02', 'Cụm Database Quản trị PostgreSQL High Availability', 'Database Services', 'Dịch vụ cơ sở dữ liệu phân tán tự động sao lưu và chuyển vùng sự cố', 8000000.00, 'Tháng', 10.00),
('SRV-DEVOPS-03', 'Gói Hỗ trợ Triển khai CI/CD & Docker Container', 'DevOps & Consulting', 'Tư vấn, cấu hình tự động hóa quy trình triển khai và giám sát', 15000000.00, 'Gói', 10.00),
('SRV-SEC-04', 'Kiểm thử An toàn Thông tin & Hardening Hệ thống', 'Cybersecurity', 'Rà quét lỗ hổng bảo mật, cấu hình WAF, reverse proxy và hardening container', 9500000.00, 'Lần', 10.00),
('SRV-SSL-05', 'Chứng chỉ Bảo mật SSL/TLS Doanh nghiệp (Wildcard)', 'Security Certificates', 'Bảo mật truyền thông mã hóa đường truyền cho toàn bộ sub-domain', 3500000.00, 'Năm', 10.00),
('SRV-MAINT-06', 'Bảo trì & Hỗ trợ Kỹ thuật Hạ tầng 24/7', 'Technical Support', 'Dịch vụ giám sát Prometheus, Grafana và trực ứng cứu sự cố 24/7', 6000000.00, 'Tháng', 10.00)
ON CONFLICT (code) DO NOTHING;

-- TẠO HÓA ĐƠN MẪU
INSERT INTO invoices (invoice_number, customer_id, issue_date, due_date, subtotal, tax_amount, discount_amount, total_amount, status, payment_method, notes) VALUES
('HD-2026-001', 1, '2026-10-01', '2026-10-15', 20500000.00, 2050000.00, 500000.00, 22050000.00, 'PAID', 'Bank Transfer', 'Thanh toán trọn gói dịch vụ Cloud Server & Database tháng 10/2026'),
('HD-2026-002', 2, '2026-10-05', '2026-10-20', 24500000.00, 2450000.00, 0.00, 26950000.00, 'PAID', 'Bank Transfer', 'Hóa đơn triển khai CI/CD Pipeline và Hardening an toàn thông tin'),
('HD-2026-003', 3, '2026-10-10', '2026-10-25', 18500000.00, 1850000.00, 0.00, 20350000.00, 'PENDING', 'Bank Transfer', 'Chi phí duy trì hệ thống Cloud Server & Bảo trì 24/7 quý IV'),
('HD-2026-004', 4, '2026-09-15', '2026-09-30', 9500000.00, 950000.00, 0.00, 10450000.00, 'OVERDUE', 'Bank Transfer', 'Đã quá hạn thanh toán dịch vụ kiểm thử bảo mật'),
('HD-2026-005', 5, '2026-10-20', '2026-11-05', 11500000.00, 1150000.00, 0.00, 12650000.00, 'PENDING', 'Bank Transfer', 'Gia hạn chứng chỉ SSL Wildcard và bảo trì hệ thống')
ON CONFLICT (invoice_number) DO NOTHING;

-- CHI TIẾT HÓA ĐƠN
INSERT INTO invoice_items (invoice_id, service_id, item_name, quantity, unit_price, tax_rate, amount) VALUES
(1, 1, 'Dịch vụ Dedicated Cloud Server (16 vCPU, 64GB RAM)', 1.00, 12500000.00, 10.00, 12500000.00),
(1, 2, 'Cụm Database Quản trị PostgreSQL High Availability', 1.00, 8000000.00, 10.00, 8000000.00),
(2, 3, 'Gói Hỗ trợ Triển khai CI/CD & Docker Container', 1.00, 15000000.00, 10.00, 15000000.00),
(2, 4, 'Kiểm thử An toàn Thông tin & Hardening Hệ thống', 1.00, 9500000.00, 10.00, 9500000.00),
(3, 1, 'Dịch vụ Dedicated Cloud Server (16 vCPU, 64GB RAM)', 1.00, 12500000.00, 10.00, 12500000.00),
(3, 6, 'Bảo trì & Hỗ trợ Kỹ thuật Hạ tầng 24/7', 1.00, 6000000.00, 10.00, 6000000.00),
(4, 4, 'Kiểm thử An toàn Thông tin & Hardening Hệ thống', 1.00, 9500000.00, 10.00, 9500000.00),
(5, 5, 'Chứng chỉ Bảo mật SSL/TLS Doanh nghiệp (Wildcard)', 1.00, 3500000.00, 10.00, 3500000.00),
(5, 6, 'Bảo trì & Hỗ trợ Kỹ thuật Hạ tầng 24/7', 1.00, 6000000.00, 10.00, 6000000.00);

-- LỊCH SỬ THANH TOÁN
INSERT INTO payments (invoice_id, payment_date, amount, payment_method, transaction_ref, notes) VALUES
(1, '2026-10-03 14:25:00+07', 22050000.00, 'Bank Transfer', 'FT262761829102', 'FPT thanh toán UNC số 8920 qua Vietcombank'),
(2, '2026-10-08 09:15:30+07', 26950000.00, 'Bank Transfer', 'VT262819280192', 'Viettel thanh toán chuyển khoản qua MBBank');

-- NHẬT KÝ KIỂM TOÁN BAN ĐẦU
INSERT INTO audit_logs (action, entity_type, entity_id, details, ip_address) VALUES
('INIT_SYSTEM', 'SYSTEM', 1, 'Khởi tạo cơ sở dữ liệu mẫu Hệ thống Quản lý Hóa đơn', '127.0.0.1'),
('PAYMENT_RECEIVED', 'INVOICE', 1, 'Xác nhận thanh toán 22,050,000 VND cho hóa đơn HD-2026-001', '192.168.1.100'),
('PAYMENT_RECEIVED', 'INVOICE', 2, 'Xác nhận thanh toán 26,950,000 VND cho hóa đơn HD-2026-002', '192.168.1.100');
