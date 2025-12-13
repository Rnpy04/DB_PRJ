-- ================================================
-- Phase 5: View Design and Implementation
-- ================================================
-- طراحی view‌ها برای دسترسی محدود و امن به داده‌ها

-- ================================================
-- VIEW 1: vw_customer_accounts_summary
-- خلاصه حساب‌های هر مشتری
-- ================================================
-- هدف: نمایش اطلاعات خلاصه حساب‌های مشتریان بدون نمایش جزئیات حساس
-- ستون‌های حذف شده: آدرس کامل، ایمیل، شماره ملی کامل
-- مناسب برای: تیم پشتیبانی مشتریان، داشبورد مدیریتی

CREATE OR REPLACE VIEW vw_customer_accounts_summary AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    -- نمایش 4 رقم آخر شماره ملی برای حفظ حریم خصوصی
    '******' || SUBSTRING(c.national_id FROM 7 FOR 4) AS masked_national_id,
    -- نمایش کد استان تلفن فقط
    SUBSTRING(c.phone FROM 1 FOR 4) || '***' || SUBSTRING(c.phone FROM 8 FOR 4) AS masked_phone,
    COUNT(a.account_number) AS total_accounts,
    COUNT(CASE WHEN a.status = 'ACTIVE' THEN 1 END) AS active_accounts,
    COALESCE(SUM(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE 0 END), 0) AS total_balance,
    COALESCE(MAX(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE 0 END), 0) AS highest_balance,
    MIN(a.opening_date) AS first_account_date,
    MAX(a.opening_date) AS latest_account_date
FROM customer c
LEFT JOIN account a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.national_id, c.phone;

COMMENT ON VIEW vw_customer_accounts_summary IS 
'خلاصه حساب‌های مشتری با اطلاعات ماسک شده برای حفظ حریم خصوصی';

-- تست View 1:
SELECT * FROM vw_customer_accounts_summary 
WHERE total_balance > 10000000
ORDER BY total_balance DESC;

-- ================================================
-- VIEW 2: vw_active_loans
-- وام‌های فعال مشتریان
-- ================================================
-- هدف: نمایش وام‌های فعال بدون دسترسی به اطلاعات حساس مشتری
-- ستون‌های حذف شده: آدرس، ایمیل، تماس کامل
-- مناسب برای: تیم وام، تحلیلگران مالی

CREATE OR REPLACE VIEW vw_active_loans AS
SELECT 
    l.loan_id,
    l.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    l.loan_type,
    l.loan_amount,
    l.remaining_amount,
    ROUND((l.remaining_amount / l.loan_amount * 100)::numeric, 2) AS remaining_percentage,
    l.interest_rate,
    l.start_date,
    l.end_date,
    -- محاسبه تعداد روزهای باقیمانده
    l.end_date - CURRENT_DATE AS days_remaining,
    -- محاسبه تعداد ماه‌های باقیمانده
    EXTRACT(YEAR FROM AGE(l.end_date, CURRENT_DATE)) * 12 + 
    EXTRACT(MONTH FROM AGE(l.end_date, CURRENT_DATE)) AS months_remaining,
    l.account_number,
    b.branch_name
FROM loan l
JOIN customer c ON l.customer_id = c.customer_id
JOIN account a ON l.account_number = a.account_number
JOIN branch b ON a.branch_code = b.branch_code
WHERE l.status = 'ACTIVE';

COMMENT ON VIEW vw_active_loans IS 
'نمایش وام‌های فعال با محاسبات مالی بدون اطلاعات حساس';

-- تست View 2:
SELECT * FROM vw_active_loans 
WHERE remaining_percentage > 80
ORDER BY remaining_amount DESC;

-- ================================================
-- VIEW 3: vw_recent_transactions_30days
-- تراکنش‌های 30 روز اخیر
-- ================================================
-- هدف: نمایش تراکنش‌های اخیر بدون نمایش مبالغ دقیق برای همه کاربران
-- ستون‌های تغییر یافته: دسته‌بندی مبالغ به جای نمایش دقیق
-- مناسب برای: تیم تحلیل، گزارش‌گیری

CREATE OR REPLACE VIEW vw_recent_transactions_30days AS
SELECT 
    t.transaction_id,
    t.transaction_type,
    -- دسته‌بندی مبلغ به جای نمایش دقیق
    CASE 
        WHEN t.amount < 1000000 THEN 'کمتر از 1 میلیون'
        WHEN t.amount < 5000000 THEN '1 تا 5 میلیون'
        WHEN t.amount < 10000000 THEN '5 تا 10 میلیون'
        WHEN t.amount < 50000000 THEN '10 تا 50 میلیون'
        ELSE 'بیش از 50 میلیون'
    END AS amount_range,
    t.transaction_date,
    TO_CHAR(t.transaction_date, 'YYYY-MM-DD') AS transaction_day,
    TO_CHAR(t.transaction_date, 'HH24:MI') AS transaction_time,
    -- نمایش 4 رقم اول و آخر شماره حساب
    SUBSTRING(t.source_account FROM 1 FOR 4) || '****' || 
    SUBSTRING(t.source_account FROM 13 FOR 4) AS masked_source,
    CASE 
        WHEN t.destination_account IS NOT NULL 
        THEN SUBSTRING(t.destination_account FROM 1 FOR 4) || '****' || 
             SUBSTRING(t.destination_account FROM 13 FOR 4)
        ELSE NULL
    END AS masked_destination,
    t.status,
    -- حذف توضیحات حساس
    CASE 
        WHEN LENGTH(t.description) > 20 
        THEN SUBSTRING(t.description FROM 1 FOR 20) || '...'
        ELSE t.description
    END AS short_description
FROM transaction t
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  AND t.status = 'COMPLETED';

COMMENT ON VIEW vw_recent_transactions_30days IS 
'تراکنش‌های 30 روز اخیر با اطلاعات ماسک شده برای گزارش‌گیری';

-- تست View 3:
SELECT 
    transaction_day,
    transaction_type,
    amount_range,
    COUNT(*) AS count
FROM vw_recent_transactions_30days
GROUP BY transaction_day, transaction_type, amount_range
ORDER BY transaction_day DESC, transaction_type;

-- ================================================
-- VIEW 4: vw_branch_performance
-- عملکرد شعب (View اختیاری)
-- ================================================
-- هدف: ارائه آمار عملکرد هر شعبه بدون دسترسی به اطلاعات مشتریان
-- مناسب برای: مدیریت ارشد، تحلیل عملکرد

CREATE OR REPLACE VIEW vw_branch_performance AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.manager_name,
    -- تعداد حساب‌های فعال
    COUNT(DISTINCT a.account_number) AS total_accounts,
    COUNT(DISTINCT CASE WHEN a.status = 'ACTIVE' THEN a.account_number END) AS active_accounts,
    -- تعداد مشتریان
    COUNT(DISTINCT a.customer_id) AS total_customers,
    -- موجودی کل
    COALESCE(SUM(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE 0 END), 0) AS total_balance,
    -- میانگین موجودی
    COALESCE(AVG(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE NULL END), 0)::bigint AS avg_balance,
    -- تعداد کارمندان
    (SELECT COUNT(*) FROM employee e WHERE e.branch_code = b.branch_code) AS employee_count,
    -- تعداد وام‌های فعال
    (SELECT COUNT(*) 
     FROM loan l 
     JOIN account a2 ON l.account_number = a2.account_number 
     WHERE a2.branch_code = b.branch_code AND l.status = 'ACTIVE') AS active_loans,
    -- مجموع وام‌های فعال
    (SELECT COALESCE(SUM(l.remaining_amount), 0)
     FROM loan l 
     JOIN account a2 ON l.account_number = a2.account_number 
     WHERE a2.branch_code = b.branch_code AND l.status = 'ACTIVE') AS total_loan_amount
FROM branch b
LEFT JOIN account a ON b.branch_code = a.branch_code
GROUP BY b.branch_code, b.branch_name, b.manager_name;

COMMENT ON VIEW vw_branch_performance IS 
'آمار عملکرد شعب بدون اطلاعات حساس مشتریان';

-- تست View 4:
SELECT * FROM vw_branch_performance
ORDER BY total_balance DESC;

-- ================================================
-- Additional Queries for Testing Views
-- ================================================

-- Query 1: مشتریان با بالاترین موجودی کل
SELECT * FROM vw_customer_accounts_summary
WHERE active_accounts > 0
ORDER BY total_balance DESC
LIMIT 10;

-- Query 2: وام‌های نزدیک به سررسید (کمتر از 6 ماه)
SELECT 
    customer_name,
    loan_type,
    remaining_amount,
    months_remaining,
    end_date
FROM vw_active_loans
WHERE months_remaining < 6
ORDER BY months_remaining ASC;

-- Query 3: آمار روزانه تراکنش‌های اخیر
SELECT 
    transaction_day,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT masked_source) AS unique_accounts
FROM vw_recent_transactions_30days
GROUP BY transaction_day
ORDER BY transaction_day DESC;

-- Query 4: مقایسه عملکرد شعب
SELECT 
    branch_name,
    total_customers,
    active_accounts,
    total_balance / 1000000 AS balance_millions,
    employee_count,
    CASE 
        WHEN employee_count > 0 
        THEN (total_customers::float / employee_count)::numeric(10,2)
        ELSE 0
    END AS customers_per_employee
FROM vw_branch_performance
ORDER BY total_balance DESC;

-- ================================================
-- Security Check: Verify Views Don't Expose Sensitive Data
-- ================================================

-- بررسی ساختار view‌ها
SELECT 
    table_name,
    view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'vw_%'
ORDER BY table_name;

-- ================================================
-- Performance Analysis of Views
-- ================================================

-- تحلیل عملکرد View 1
EXPLAIN ANALYZE
SELECT * FROM vw_customer_accounts_summary
WHERE total_balance > 5000000;

-- تحلیل عملکرد View 2
EXPLAIN ANALYZE
SELECT * FROM vw_active_loans
WHERE loan_type = 'HOME';

-- تحلیل عملکرد View 3
EXPLAIN ANALYZE
SELECT * FROM vw_recent_transactions_30days
WHERE transaction_type = 'TRANSFER';

-- ================================================
-- Display Success Message
-- ================================================
DO $$
BEGIN
    RAISE NOTICE 'تمام View‌ها با موفقیت ایجاد شدند!';
    RAISE NOTICE 'تعداد View‌ها: 4';
    RAISE NOTICE '✓ vw_customer_accounts_summary - خلاصه حساب‌ها';
    RAISE NOTICE '✓ vw_active_loans - وام‌های فعال';
    RAISE NOTICE '✓ vw_recent_transactions_30days - تراکنش‌های اخیر';
    RAISE NOTICE '✓ vw_branch_performance - عملکرد شعب';
END $$;