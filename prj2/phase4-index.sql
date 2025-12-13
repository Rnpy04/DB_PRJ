-- ================================================
-- Phase 4: Index Design and Implementation
-- ================================================
-- تحلیل و طراحی ایندکس‌ها برای بهبود عملکرد پایگاه داده

-- ================================================
-- INDEX 1: customer_national_id_idx
-- جدول: customer
-- ستون: national_id
-- ================================================
-- دلیل انتخاب:
-- 1. شماره ملی در کوئری‌های WHERE برای جستجوی مشتریان استفاده می‌شود
-- 2. این ستون UNIQUE است و کاربر�� زیادی دارد
-- 3. جستجوی مشتری بر اساس شماره ملی از عملیات‌های پرتکرار است
-- 4. بدون ایندکس، جستجو به صورت Full Table Scan انجام می‌شود

CREATE INDEX idx_customer_national_id ON customer(national_id);

COMMENT ON INDEX idx_customer_national_id IS 
'ایندکس برای جستجوی سریع مشتریان با شماره ملی - استفاده در احراز هویت و جستجو';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM customer WHERE national_id = '1234567890';

-- ================================================
-- INDEX 2: account_customer_branch_idx
-- جدول: account
-- ستون‌ها: customer_id, branch_code, status
-- ================================================
-- دلیل انتخاب:
-- 1. کوئری‌های متداول برای یافتن حساب‌های فعال یک مشتری در یک شعبه
-- 2. ترکیب این سه ستون در WHERE clause پرتکرار است
-- 3. Composite Index برای کوئری‌های فیلتر شده بر اساس مشتری، شعبه و وضعیت
-- 4. بهبود عملکرد در گزارش‌گیری و تحلیل‌های آماری

CREATE INDEX idx_account_customer_branch_status 
ON account(customer_id, branch_code, status);

COMMENT ON INDEX idx_account_customer_branch_status IS 
'ایندکس ترکیبی برای جستجوی حساب‌ها بر اساس مشتری، شعبه و وضعیت - بهبود کوئری‌های فیلتر شده';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM account 
WHERE customer_id = 1 
  AND branch_code = 'BR001' 
  AND status = 'ACTIVE';

-- ================================================
-- INDEX 3: transaction_date_idx
-- جدول: transaction
-- ستون: transaction_date
-- ================================================
-- دلیل انتخاب:
-- 1. کوئری‌های گزارش‌گیری بر اساس بازه زمانی بسیار متداول است
-- 2. مرتب‌سازی (ORDER BY) بر اساس تاریخ در اکثر کوئری‌ها
-- 3. جستجوی تراکنش‌های اخیر (BETWEEN, >=, <=) پرکاربرد است
-- 4. B-tree index برای range queries مناسب است

CREATE INDEX idx_transaction_date ON transaction(transaction_date DESC);

COMMENT ON INDEX idx_transaction_date IS 
'ایندکس برای جستجوی سریع تراکنش‌ها در بازه‌های زمانی و مرتب‌سازی - DESC برای کوئری‌های اخیر';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM transaction 
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY transaction_date DESC;

-- ================================================
-- INDEX 4: transaction_accounts_idx
-- جدول: transaction
-- ستون‌ها: source_account, destination_account
-- ================================================
-- دلیل انتخاب:
-- 1. جستجوی تراکنش‌های مربوط به یک حساب خاص (مبدا یا مقصد) بسیار متداول
-- 2. کوئری‌های تاریخچه تراکنش هر حساب پرتکرار است
-- 3. دو ایندکس جداگانه برای source و destination به دلیل الگوهای جستجوی متفاوت

CREATE INDEX idx_transaction_source_account 
ON transaction(source_account, transaction_date DESC);

CREATE INDEX idx_transaction_destination_account 
ON transaction(destination_account, transaction_date DESC);

COMMENT ON INDEX idx_transaction_source_account IS 
'ایندکس برای جستجوی سریع تراکنش‌ها بر اساس حساب مبدا و تاریخ';

COMMENT ON INDEX idx_transaction_destination_account IS 
'ایندکس برای جستجوی سریع تراکنش‌ها بر اساس حساب مقصد و تاریخ';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM transaction 
WHERE source_account = '1001000100010001'
ORDER BY transaction_date DESC
LIMIT 10;

-- ================================================
-- INDEX 5: loan_customer_status_idx
-- جدول: loan
-- ستون‌ها: customer_id, status
-- ================================================
-- دلیل انتخاب:
-- 1. کوئری‌های یافتن وام‌های فعال یک مشتری بسیار متداول
-- 2. گزارش‌گیری از وام‌های فعال/تسویه شده
-- 3. Composite index برای فیلتر کردن بر اساس مشتری و وضعیت وام
-- 4. بهبود عملکرد در محاسبات مالی و تحلیل‌های اعتباری

CREATE INDEX idx_loan_customer_status 
ON loan(customer_id, status, remaining_amount);

COMMENT ON INDEX idx_loan_customer_status IS 
'ایندکس ترکیبی برای جستجوی وام‌ها بر اساس مشتری، وضعیت و مبلغ باقیمانده';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM loan 
WHERE customer_id = 1 
  AND status = 'ACTIVE'
ORDER BY remaining_amount DESC;

-- ================================================
-- INDEX 6: payment_account_date_idx
-- جدول: payment
-- ستون‌ها: account_number, payment_date
-- ================================================
-- دلیل انتخاب:
-- 1. جستجوی تاریخچه پرداخت‌های یک حساب خاص
-- 2. گزارش‌گیری پرداخت‌ها در بازه زمانی مشخص
-- 3. Composite index برای کوئری‌های فیلتر شده همزمان بر اساس حساب و تاریخ

CREATE INDEX idx_payment_account_date 
ON payment(account_number, payment_date DESC);

COMMENT ON INDEX idx_payment_account_date IS 
'ایندکس برای جستجوی سریع پرداخت‌های یک حساب بر اساس تاریخ';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM payment 
WHERE account_number = '1001000100010001'
  AND payment_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY payment_date DESC;

-- ================================================
-- INDEX 7: card_account_status_idx
-- جدول: card
-- ستون‌ها: account_number, status
-- ================================================
-- دلیل انتخاب:
-- 1. جستجوی کارت‌های فعال یک حساب بانکی
-- 2. کوئری‌های مدیریت کارت و بررسی وضعیت
-- 3. فیلتر کردن کارت‌ها بر اساس حساب و وضعیت همزمان

CREATE INDEX idx_card_account_status 
ON card(account_number, status);

COMMENT ON INDEX idx_card_account_status IS 
'ایندکس برای جستجوی کارت‌های یک حساب بر اساس وضعیت';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM card 
WHERE account_number = '1001000100010001'
  AND status = 'ACTIVE';

-- ================================================
-- INDEX 8: employee_branch_idx
-- جدول: employee
-- ستون: branch_code
-- ================================================
-- دلیل انتخاب:
-- 1. جستجوی کارمندان یک شعبه خاص
-- 2. گزارش‌گیری از نیروی انسانی هر شعبه
-- 3. Foreign key است و در JOIN operations پرتکرار استفاده می‌شود

CREATE INDEX idx_employee_branch 
ON employee(branch_code);

COMMENT ON INDEX idx_employee_branch IS 
'ایندکس برای جستجوی کارمندان بر اساس شعبه - بهبود JOIN performance';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT e.*, b.branch_name 
FROM employee e
JOIN branch b ON e.branch_code = b.branch_code
WHERE e.branch_code = 'BR001';

-- ================================================
-- PARTIAL INDEX: active_accounts_idx
-- جدول: account
-- ستون: balance
-- فیلتر: status = 'ACTIVE'
-- ================================================
-- دلیل انتخاب:
-- 1. Partial index برای حساب‌های فعال که اکثر کوئری‌ها روی آن‌ها هستند
-- 2. کاهش حجم ایندکس با فیلتر کردن رکوردهای غیرفعال
-- 3. بهبود عملکرد در کوئری‌های مربوط به موجودی حساب‌های فعال

CREATE INDEX idx_active_accounts_balance 
ON account(balance DESC) 
WHERE status = 'ACTIVE';

COMMENT ON INDEX idx_active_accounts_balance IS 
'Partial index برای موجودی حساب‌های فعال - کاهش حجم و بهبود سرعت';

-- تست عملکرد:
EXPLAIN ANALYZE
SELECT * FROM account 
WHERE status = 'ACTIVE' 
  AND balance > 10000000
ORDER BY balance DESC;

-- ================================================
-- تحلیل و گزارش ایندکس‌ها
-- ================================================

-- مشاهده تمام ایندکس‌های ایجاد شده
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- اندازه ایندکس‌ها
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;

-- آمار استفاده از ایندکس‌ها (بعد از مدتی استفاده)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- ================================================
-- نتیجه‌گیری و توصیه‌ها
-- ================================================

/*
خلاصه ایندکس‌های طراحی شده:

1. idx_customer_national_id - جستجوی مشتری با شماره ملی
2. idx_account_customer_branch_status - جستجوی حساب‌ها (composite)
3. idx_transaction_date - جستجوی تراکنش‌ها بر اساس تاریخ
4. idx_transaction_source_account - تراکنش‌های حساب مبدا
5. idx_transaction_destination_account - تراکنش‌های حساب مقصد
6. idx_loan_customer_status - جستجوی وام‌ها (composite)
7. idx_payment_account_date - جستجوی پرداخت‌ها (composite)
8. idx_card_account_status - جستجوی کارت‌ها
9. idx_employee_branch - جستجوی کارمندان بر اساس شعبه
10. idx_active_accounts_balance - Partial index برای حساب‌های فعال

مزایا:
✓ بهبود چشمگیر سرعت کوئری‌های SELECT
✓ کاهش زمان پاسخ در گزارش‌گیری
✓ بهینه‌سازی JOIN operations
✓ پشتیبانی از Range queries و Sorting

معایب (قابل قبول):
- افزایش جزئی در زمان INSERT/UPDATE/DELETE
- استفاده از فضای ذخیره‌سازی اضافی (معمولاً 10-20% جداول)

توصیه‌ها:
1. مانیتور کردن استفاده از ایندکس‌ها با pg_stat_user_indexes
2. حذف ایندکس‌های استفاده نشده (idx_scan = 0)
3. REINDEX در صورت نیاز برای بهبود عملکرد
4. تحلیل دوره‌ای با EXPLAIN ANALYZE
*/

DO $$
BEGIN
    RAISE NOTICE 'تمام ایندکس‌ها با موفقیت ایجاد شدند!';
    RAISE NOTICE 'تعداد ایندکس‌ها: 10';
    RAISE NOTICE 'لطفاً از EXPLAIN ANALYZE برای تست عملکرد استفاده کنید';
END $$;