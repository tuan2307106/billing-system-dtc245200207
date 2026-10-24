import os
import time
import logging
from datetime import datetime, date
from decimal import Decimal
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, Response
import psycopg2
from psycopg2.extras import RealDictCursor
import prometheus_client
from prometheus_client import Counter, Histogram, Gauge

# CẤU HÌNH LOGGING
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] [%(name)s] %(message)s'
)
logger = logging.getLogger("BillingApp")

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "smart_billing_super_secret_key_2026")

# CẤU HÌNH DATABASE POSTGRESQL
DB_HOST = os.getenv("DB_HOST", "billing-db")
DB_PORT = int(os.getenv("DB_PORT", 5432))
DB_NAME = os.getenv("DB_NAME", "billing_db")
DB_USER = os.getenv("DB_USER", "billing_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "BillingSecure2026!Pass")

# ĐỊNH NGHĨA CÁC CHỈ SỐ PROMETHEUS METRICS
REQUEST_COUNT = Counter(
    'billing_http_requests_total',
    'Total HTTP requests processed by Billing Web App',
    ['method', 'endpoint', 'http_status']
)
REQUEST_LATENCY = Histogram(
    'billing_http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['endpoint']
)
INVOICES_COUNT_GAUGE = Gauge(
    'billing_invoices_count',
    'Current number of invoices grouped by status',
    ['status']
)
TOTAL_REVENUE_GAUGE = Gauge(
    'billing_revenue_total_vnd',
    'Total revenue received from paid invoices in VND'
)

def get_db_connection():
    """Tạo kết nối an toàn tới cơ sở dữ liệu PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            cursor_factory=RealDictCursor,
            connect_timeout=5
        )
        return conn
    except Exception as e:
        logger.error(f"Lỗi kết nối cơ sở dữ liệu PostgreSQL ({DB_HOST}:{DB_PORT}): {str(e)}")
        return None

def update_prometheus_business_metrics():
    """Cập nhật các số liệu kinh doanh vào Prometheus Gauges"""
    conn = get_db_connection()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            # Đếm số lượng hóa đơn theo trạng thái
            cur.execute("SELECT status, COUNT(*) as count FROM invoices GROUP BY status;")
            rows = cur.fetchall()
            statuses = ['DRAFT', 'PENDING', 'PAID', 'OVERDUE', 'CANCELLED']
            status_map = {r['status']: r['count'] for r in rows}
            for s in statuses:
                INVOICES_COUNT_GAUGE.labels(status=s).set(status_map.get(s, 0))

            # Tổng doanh thu từ hóa đơn PAID
            cur.execute("SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE status = 'PAID';")
            rev_row = cur.fetchone()
            if rev_row:
                TOTAL_REVENUE_GAUGE.set(float(rev_row['total']))
    except Exception as e:
        logger.warning(f"Lỗi cập nhật Prometheus business metrics: {str(e)}")
    finally:
        conn.close()

# MIDDLEWARE ĐO LƯỜNG REQUEST LATENCY VÀ COUNT CHO PROMETHEUS
@app.before_request
def start_timer():
    request.start_time = time.time()

@app.after_request
def record_metrics(response):
    if hasattr(request, 'start_time'):
        resp_time = time.time() - request.start_time
        endpoint = request.endpoint or 'unknown'
        REQUEST_LATENCY.labels(endpoint=endpoint).observe(resp_time)
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=endpoint,
            http_status=response.status_code
        ).inc()
    return response

# JINJA FILTER ĐỊNH DẠNG TIỀN TỆ VND
@app.template_filter('vnd')
def format_vnd(value):
    if value is None:
        return "0 ₫"
    try:
        val = float(value)
        return f"{val:,.0f} ₫".replace(",", ".")
    except (ValueError, TypeError):
        return f"{value} ₫"

@app.template_filter('date_format')
def format_date(value, fmt='%d/%m/%Y'):
    if not value:
        return ""
    if isinstance(value, (datetime, date)):
        return value.strftime(fmt)
    return str(value)

# =============================================================================
# CÁC ROUTE NGHIỆP VỤ (BUSINESS ROUTES)
# =============================================================================

@app.route('/')
def dashboard():
    """Trang chủ hiển thị thống kê tổng quan hóa đơn & doanh thu"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Không thể kết nối đến máy chủ cơ sở dữ liệu PostgreSQL."), 500

    try:
        with conn.cursor() as cur:
            # Tổng doanh thu đã thu
            cur.execute("SELECT COALESCE(SUM(total_amount), 0) as paid_revenue FROM invoices WHERE status = 'PAID';")
            paid_revenue = cur.fetchone()['paid_revenue']

            # Doanh thu chờ thanh toán (PENDING)
            cur.execute("SELECT COALESCE(SUM(total_amount), 0) as pending_revenue FROM invoices WHERE status = 'PENDING';")
            pending_revenue = cur.fetchone()['pending_revenue']

            # Đếm số hóa đơn
            cur.execute("SELECT COUNT(*) as total_invoices FROM invoices;")
            total_invoices = cur.fetchone()['total_invoices']

            cur.execute("SELECT COUNT(*) as paid_count FROM invoices WHERE status = 'PAID';")
            paid_count = cur.fetchone()['paid_count']

            cur.execute("SELECT COUNT(*) as pending_count FROM invoices WHERE status = 'PENDING';")
            pending_count = cur.fetchone()['pending_count']

            cur.execute("SELECT COUNT(*) as overdue_count FROM invoices WHERE status = 'OVERDUE';")
            overdue_count = cur.fetchone()['overdue_count']

            cur.execute("SELECT COUNT(*) as total_customers FROM customers;")
            total_customers = cur.fetchone()['total_customers']

            # Danh sách hóa đơn mới nhất
            cur.execute("""
                SELECT i.*, c.name as customer_name, c.company
                FROM invoices i
                JOIN customers c ON i.customer_id = c.id
                ORDER BY i.created_at DESC
                LIMIT 5;
            """)
            recent_invoices = cur.fetchall()

        stats = {
            'paid_revenue': paid_revenue,
            'pending_revenue': pending_revenue,
            'total_invoices': total_invoices,
            'paid_count': paid_count,
            'pending_count': pending_count,
            'overdue_count': overdue_count,
            'total_customers': total_customers
        }
        return render_template('dashboard.html', stats=stats, recent_invoices=recent_invoices)
    finally:
        conn.close()

@app.route('/invoices')
def invoices_list():
    """Danh sách hóa đơn có bộ lọc trạng thái và tìm kiếm"""
    status_filter = request.args.get('status', '').strip()
    search_query = request.args.get('q', '').strip()

    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    try:
        with conn.cursor() as cur:
            sql = """
                SELECT i.*, c.name as customer_name, c.company, c.customer_code
                FROM invoices i
                JOIN customers c ON i.customer_id = c.id
                WHERE 1=1
            """
            params = []
            if status_filter:
                sql += " AND i.status = %s"
                params.append(status_filter)
            if search_query:
                sql += " AND (i.invoice_number ILIKE %s OR c.name ILIKE %s OR c.company ILIKE %s)"
                search_val = f"%{search_query}%"
                params.extend([search_val, search_val, search_val])

            sql += " ORDER BY i.created_at DESC;"
            cur.execute(sql, tuple(params))
            invoices = cur.fetchall()

        return render_template('invoices.html', invoices=invoices, status_filter=status_filter, search_query=search_query)
    finally:
        conn.close()

@app.route('/invoices/create', methods=['GET', 'POST'])
def invoice_create():
    """Tạo hóa đơn mới với danh mục dịch vụ động"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    if request.method == 'GET':
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM customers ORDER BY name ASC;")
                customers = cur.fetchall()
                cur.execute("SELECT * FROM services WHERE is_active = TRUE ORDER BY name ASC;")
                services = cur.fetchall()

                # Tự sinh mã hóa đơn HD-YYYYMM-XXX
                cur.execute("SELECT COUNT(*) as count FROM invoices;")
                next_id = cur.fetchone()['count'] + 1
                default_invoice_number = f"HD-{datetime.now().strftime('%Y%m')}-{next_id:04d}"

            return render_template('invoice_create.html', customers=customers, services=services, default_invoice_number=default_invoice_number)
        finally:
            conn.close()

    # XỬ LÝ POST TẠO HÓA ĐƠN
    try:
        customer_id = int(request.form.get('customer_id'))
        invoice_number = request.form.get('invoice_number', '').strip()
        issue_date = request.form.get('issue_date')
        due_date = request.form.get('due_date')
        payment_method = request.form.get('payment_method', 'Bank Transfer')
        notes = request.form.get('notes', '')

        # Thu thập các dòng mặt hàng
        item_names = request.form.getlist('item_name[]')
        quantities = request.form.getlist('quantity[]')
        unit_prices = request.form.getlist('unit_price[]')
        tax_rates = request.form.getlist('tax_rate[]')

        subtotal = Decimal('0.00')
        tax_total = Decimal('0.00')
        items_data = []

        for i in range(len(item_names)):
            name = item_names[i].strip()
            if not name:
                continue
            qty = Decimal(quantities[i]) if quantities[i] else Decimal('1.0')
            price = Decimal(unit_prices[i]) if unit_prices[i] else Decimal('0.0')
            tax_rate = Decimal(tax_rates[i]) if tax_rates[i] else Decimal('10.0')

            amount = qty * price
            tax = amount * (tax_rate / Decimal('100.0'))

            subtotal += amount
            tax_total += tax

            items_data.append({
                'name': name,
                'quantity': qty,
                'unit_price': price,
                'tax_rate': tax_rate,
                'amount': amount
            })

        discount = Decimal(request.form.get('discount_amount', '0.00') or '0.00')
        total_amount = subtotal + tax_total - discount

        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO invoices (invoice_number, customer_id, issue_date, due_date, subtotal, tax_amount, discount_amount, total_amount, status, payment_method, notes)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'PENDING', %s, %s)
                RETURNING id;
            """, (invoice_number, customer_id, issue_date, due_date, subtotal, tax_total, discount, total_amount, payment_method, notes))
            new_invoice_id = cur.fetchone()['id']

            for item in items_data:
                cur.execute("""
                    INSERT INTO invoice_items (invoice_id, item_name, quantity, unit_price, tax_rate, amount)
                    VALUES (%s, %s, %s, %s, %s, %s);
                """, (new_invoice_id, item['name'], item['quantity'], item['unit_price'], item['tax_rate'], item['amount']))

            # Ghi log kiểm toán
            cur.execute("""
                INSERT INTO audit_logs (action, entity_type, entity_id, details, ip_address)
                VALUES ('CREATE_INVOICE', 'INVOICE', %s, %s, %s);
            """, (new_invoice_id, f"Tạo mới hóa đơn {invoice_number} tổng giá trị {total_amount:,.0f} VND", request.remote_addr))

            conn.commit()

        logger.info(f"Đã tạo thành công hóa đơn mới: {invoice_number} (ID: {new_invoice_id})")
        flash(f"Đã tạo hóa đơn {invoice_number} thành công!", "success")
        return redirect(url_for('invoice_detail', invoice_id=new_invoice_id))
    except Exception as e:
        conn.rollback()
        logger.error(f"Lỗi khi tạo hóa đơn: {str(e)}")
        flash(f"Lỗi khi tạo hóa đơn: {str(e)}", "danger")
        return redirect(url_for('invoice_create'))
    finally:
        conn.close()

@app.route('/invoices/<int:invoice_id>')
def invoice_detail(invoice_id):
    """Xem chi tiết và in ấn hóa đơn chuẩn biểu mẫu điện tử VAT"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT i.*, c.customer_code, c.name as customer_name, c.company, c.email, c.phone, c.address, c.tax_id
                FROM invoices i
                JOIN customers c ON i.customer_id = c.id
                WHERE i.id = %s;
            """, (invoice_id,))
            invoice = cur.fetchone()

            if not invoice:
                flash("Không tìm thấy thông tin hóa đơn yêu cầu.", "warning")
                return redirect(url_for('invoices_list'))

            cur.execute("SELECT * FROM invoice_items WHERE invoice_id = %s ORDER BY id ASC;", (invoice_id,))
            items = cur.fetchall()

            cur.execute("SELECT * FROM payments WHERE invoice_id = %s ORDER BY payment_date DESC;", (invoice_id,))
            payments = cur.fetchall()

        return render_template('invoice_detail.html', invoice=invoice, items=items, payments=payments)
    finally:
        conn.close()

@app.route('/invoices/<int:invoice_id>/pay', methods=['POST'])
def invoice_pay(invoice_id):
    """Xác nhận thanh toán cho hóa đơn và ghi nhận giao dịch"""
    payment_method = request.form.get('payment_method', 'Bank Transfer')
    ref_no = request.form.get('transaction_ref', f"TXN-{int(time.time())}")
    note = request.form.get('note', 'Thanh toán trực tiếp qua cổng Web Billing')

    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT total_amount, invoice_number, status FROM invoices WHERE id = %s FOR UPDATE;", (invoice_id,))
            invoice = cur.fetchone()
            if not invoice:
                flash("Hóa đơn không tồn tại.", "danger")
                return redirect(url_for('invoices_list'))

            if invoice['status'] == 'PAID':
                flash("Hóa đơn này đã được thanh toán trước đó.", "info")
                return redirect(url_for('invoice_detail', invoice_id=invoice_id))

            # Cập nhật trạng thái hóa đơn sang PAID
            cur.execute("""
                UPDATE invoices
                SET status = 'PAID', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s;
            """, (invoice_id,))

            # Ghi nhận giao dịch vào bảng payments
            cur.execute("""
                INSERT INTO payments (invoice_id, amount, payment_method, transaction_ref, notes)
                VALUES (%s, %s, %s, %s, %s);
            """, (invoice_id, invoice['total_amount'], payment_method, ref_no, note))

            # Ghi log kiểm toán
            cur.execute("""
                INSERT INTO audit_logs (action, entity_type, entity_id, details, ip_address)
                VALUES ('PAY_INVOICE', 'INVOICE', %s, %s, %s);
            """, (invoice_id, f"Thanh toán thành công hóa đơn {invoice['invoice_number']} số tiền {invoice['total_amount']} VND", request.remote_addr))

            conn.commit()

        logger.info(f"Thanh toán thành công hóa đơn ID {invoice_id} ({invoice['invoice_number']})")
        flash(f"Thanh toán thành công hóa đơn {invoice['invoice_number']}!", "success")
        return redirect(url_for('invoice_detail', invoice_id=invoice_id))
    except Exception as e:
        conn.rollback()
        logger.error(f"Lỗi khi xử lý thanh toán: {str(e)}")
        flash(f"Lỗi khi xử lý thanh toán: {str(e)}", "danger")
        return redirect(url_for('invoice_detail', invoice_id=invoice_id))
    finally:
        conn.close()

@app.route('/invoices/<int:invoice_id>/delete', methods=['POST'])
def invoice_delete(invoice_id):
    """Xóa hóa đơn"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT invoice_number FROM invoices WHERE id = %s;", (invoice_id,))
            row = cur.fetchone()
            if row:
                inv_num = row['invoice_number']
                cur.execute("DELETE FROM invoices WHERE id = %s;", (invoice_id,))
                cur.execute("""
                    INSERT INTO audit_logs (action, entity_type, entity_id, details, ip_address)
                    VALUES ('DELETE_INVOICE', 'INVOICE', %s, %s, %s);
                """, (invoice_id, f"Xóa hóa đơn {inv_num}", request.remote_addr))
                conn.commit()
                flash(f"Đã xóa hóa đơn {inv_num}.", "success")
            else:
                flash("Hóa đơn không tồn tại.", "warning")
        return redirect(url_for('invoices_list'))
    except Exception as e:
        conn.rollback()
        flash(f"Lỗi khi xóa hóa đơn: {str(e)}", "danger")
        return redirect(url_for('invoices_list'))
    finally:
        conn.close()

@app.route('/customers', methods=['GET', 'POST'])
def customers():
    """Quản lý danh sách khách hàng và thêm mới khách hàng"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500

    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        company = request.form.get('company', '').strip()
        email = request.form.get('email', '').strip()
        phone = request.form.get('phone', '').strip()
        address = request.form.get('address', '').strip()
        tax_id = request.form.get('tax_id', '').strip()

        try:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) as count FROM customers;")
                next_code = f"KH-{(cur.fetchone()['count'] + 1):03d}"

                cur.execute("""
                    INSERT INTO customers (customer_code, name, company, email, phone, address, tax_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s);
                """, (next_code, name, company, email, phone, address, tax_id))
                conn.commit()
            flash(f"Đã thêm khách hàng mới: {name} ({next_code})", "success")
            return redirect(url_for('customers'))
        except Exception as e:
            conn.rollback()
            flash(f"Lỗi thêm khách hàng: {str(e)}", "danger")

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT c.*, 
                       COUNT(i.id) as total_invoices,
                       COALESCE(SUM(i.total_amount), 0) as total_amount
                FROM customers c
                LEFT JOIN invoices i ON c.id = i.customer_id
                GROUP BY c.id
                ORDER BY c.created_at DESC;
            """)
            customer_list = cur.fetchall()
        return render_template('customers.html', customers=customer_list)
    finally:
        conn.close()

@app.route('/services')
def services_list():
    """Xem danh mục dịch vụ công nghệ / sản phẩm tính cước"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM services ORDER BY id ASC;")
            services = cur.fetchall()
        return render_template('services.html', services=services)
    finally:
        conn.close()

@app.route('/reports')
def reports():
    """Báo cáo doanh thu & biểu đồ phân tích thanh toán"""
    conn = get_db_connection()
    if not conn:
        return render_template('error.html', message="Mất kết nối CSDL."), 500
    try:
        with conn.cursor() as cur:
            # Doanh thu theo tháng
            cur.execute("""
                SELECT TO_CHAR(issue_date, 'YYYY-MM') as month,
                       SUM(CASE WHEN status = 'PAID' THEN total_amount ELSE 0 END) as paid_amount,
                       SUM(CASE WHEN status = 'PENDING' THEN total_amount ELSE 0 END) as pending_amount,
                       COUNT(*) as invoice_count
                FROM invoices
                GROUP BY TO_CHAR(issue_date, 'YYYY-MM')
                ORDER BY month ASC;
            """)
            monthly_data = cur.fetchall()

            # Phân bố trạng thái
            cur.execute("""
                SELECT status, COUNT(*) as count, SUM(total_amount) as total
                FROM invoices
                GROUP BY status;
            """)
            status_dist = cur.fetchall()
        return render_template('reports.html', monthly_data=monthly_data, status_dist=status_dist)
    finally:
        conn.close()

# =============================================================================
# CÁC ENDPOINT QUẢN TRỊ HỆ THỐNG & MONITORING
# =============================================================================

@app.route('/health')
def health_check():
    """Endpoint kiểm tra trạng thái hoạt động (Healthcheck)"""
    conn = get_db_connection()
    db_status = "UP" if conn else "DOWN"
    if conn:
        conn.close()

    status_code = 200 if db_status == "UP" else 503
    return jsonify({
        "status": "UP" if db_status == "UP" else "DEGRADED",
        "service": "billing-management-web",
        "database": db_status,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), status_code

@app.route('/metrics')
def metrics():
    """Endpoint thu thập chỉ số định dạng Prometheus scraper"""
    update_prometheus_business_metrics()
    return Response(
        prometheus_client.generate_latest(),
        mimetype="text/plain; version=0.0.4; charset=utf-8"
    )

if __name__ == '__main__':
    port = int(os.getenv("PORT", 5000))
    debug_mode = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    logger.info(f"Khởi động Smart Billing System trên cổng {port} (Debug: {debug_mode})")
    app.run(host='0.0.0.0', port=port, debug=debug_mode)
