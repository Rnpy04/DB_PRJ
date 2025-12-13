-- ================================================
-- Phase 9 (Bonus): Audit and Logging System
-- ================================================
-- سیستم ثبت رخدادها برای ردگیری تغییرات و امنیت

-- ================================================
-- جدول Audit Log
-- ================================================

DROP TABLE IF EXISTS audit_log CASCADE;

CREATE TABLE audit_log (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation_type VARCHAR(10) NOT NULL,
    record_id VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    application_name VARCHAR(100),
    CONSTRAINT chk_operation CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX idx_audit_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_changed_at ON audit_log(changed_at DESC);
CREATE INDEX idx_audit_changed_by ON audit_log(changed_by);
CREATE INDEX idx_audit_operation ON audit_log(operation_type);

COMMENT ON TABLE audit_log IS 
'جدول ثبت تمام تغییرات در جداول حساس سیستم';

COMMENT ON COLUMN audit_log.table_name IS 'نام جدولی که تغییر کرده';
COMMENT ON COLUMN audit_log.operation_type IS 'نوع عملیات: INSERT, UPDATE, DELETE';
COMMENT ON COLUMN audit_log.record_id IS 'شناسه رکورد تغییر یافته';
COMMENT ON COLUMN audit_log.old_values IS 'مقادیر قبلی به صورت JSON';
COMMENT ON COLUMN audit_log.new_values IS 'مقادیر جدید به صورت JSON';
COMMENT ON COLUMN audit_log.changed_by IS 'نام کاربر که تغییر را انجام داده';
COMMENT ON COLUMN audit_log.changed_at IS 'زمان دقیق تغییر';

-- ================================================
-- Function برای ثبت در Audit Log
-- ================================================

CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_record_id TEXT;
BEGIN
    -- تبدیل داده‌های قدیمی و جدید به JSON
    IF (TG_OP = 'DELETE') THEN
        v_old_data := row_to_json(OLD)::JSONB;
        v_new_data := NULL;
        v_record_id := OLD::TEXT;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_old_data := row_to_json(OLD)::JSONB;
        v_new_data := row_to_json(NEW)::JSONB;
        v_record_id := NEW::TEXT;
    ELSIF (TG_OP = 'INSERT') THEN
        v_old_data := NULL;
        v_new_data := row_to_json(NEW)::JSONB;
        v_record_id := NEW::TEXT;
    END IF;

    -- ثبت در جدول Audit
    INSERT INTO audit_log (
        table_name,
        operation_type,
        record_id,
        old_values,
        new_values,
        changed_by,
        changed_at,
        ip_address,
        application_name
    )
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        SUBSTRING(v_record_id FROM 1 FOR 50),
        v_old_data,
        v_new_data,
        CURRENT_USER,
        CURRENT_TIMESTAMP,
        inet_client_addr(),
        CURRENT_SETTING('application_name', true)
    );

    -- بازگشت مقدار مناسب
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_audit_trigger IS 
'Function برای ثبت خودکار تغییرات در audit_log';

-- ================================================
-- اعمال Trigger به جداول حساس
-- ================================================

-- Trigger برای جدول Customer
CREATE TRIGGER trg_audit_customer
AFTER INSERT OR UPDATE OR DELETE ON customer
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Trigger برای جدول Account
CREATE TRIGGER trg_audit_account
AFTER INSERT OR UPDATE OR DELETE ON account
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Trigger برای جدول Transaction
CREATE TRIGGER trg_audit_transaction
AFTER INSERT OR UPDATE OR DELETE ON transaction
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Trigger برای جدول Loan
CREATE TRIGGER trg_audit_loan
AFTER INSERT OR UPDATE OR DELETE ON loan
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Trigger برای جدول Payment
CREATE TRIGGER trg_audit_payment
AFTER INSERT OR UPDATE OR DELETE ON payment
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Trigger برای جدول Card
CREATE TRIGGER trg_audit_card
AFTER INSERT OR UPDATE OR DELETE ON card
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

RAISE NOTICE '✓ Audit Triggers برای 6 جدول حساس ایجاد شدند';

-- ================================================
-- View برای نمایش آسان Audit Log
-- ================================================

-- View 1: تغییرات اخیر حساب‌ها
CREATE OR REPLACE VIEW vw_audit_account_changes AS
SELECT 
    audit_id,
    operation_type,
    changed_by,
    changed_at,
    (new_values->>'account_number') AS account_number,
    (old_values->>'balance')::NUMERIC AS old_balance,
    (new_values->>'balance')::NUMERIC AS new_balance,
    (new_values->>'balance')::NUMERIC - (old_values->>'balance')::NUMERIC AS balance_change,
    (old_values->>'status') AS old_status,
    (new_values->>'status') AS new_status
FROM audit_log
WHERE table_name = 'account'
  AND operation_type IN ('UPDATE', 'INSERT')
ORDER BY changed_at DESC;

COMMENT ON VIEW vw_audit_account_changes IS 
'نمایش تغییرات حساب‌ها با جزئیات موجودی و وضعیت';

-- View 2: تاریخچه تغییرات وام‌ها
CREATE OR REPLACE VIEW vw_audit_loan_history AS
SELECT 
    audit_id,
    operation_type,
    changed_by,
    changed_at,
    (new_values->>'loan_id')::INTEGER AS loan_id,
    (new_values->>'customer_id')::INTEGER AS customer_id,
    (new_values->>'loan_type') AS loan_type,
    (old_values->>'remaining_amount')::NUMERIC AS old_remaining,
    (new_values->>'remaining_amount')::NUMERIC AS new_remaining,
    (old_values->>'status') AS old_status,
    (new_values->>'status') AS new_status
FROM audit_log
WHERE table_name = 'loan'
ORDER BY changed_at DESC;

COMMENT ON VIEW vw_audit_loan_history IS 
'تاریخچه کامل تغییرات وام‌ها';

-- View 3: آمار کلی Audit
CREATE OR REPLACE VIEW vw_audit_statistics AS
SELECT 
    table_name,
    operation_type,
    COUNT(*) AS operation_count,
    COUNT(DISTINCT changed_by) AS unique_users,
    MIN(changed_at) AS first_change,
    MAX(changed_at) AS last_change
FROM audit_log
GROUP BY table_name, operation_type
ORDER BY table_name, operation_type;

COMMENT ON VIEW vw_audit_statistics IS 
'آمار کلی عملیات‌های ثبت شده در Audit Log';

-- ================================================
-- تست سیستم Audit
-- ================================================

RAISE NOTICE '';
RAISE NOTICE '========== شروع تست‌های Audit System ==========';

-- تست 1: تغییر موجودی حساب
DO $$
DECLARE
    v_audit_count_before INTEGER;
    v_audit_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_audit_count_before FROM audit_log WHERE table_name = 'account';
    
    UPDATE account 
    SET balance = balance + 100000 
    WHERE account_number = '1001000100010001';
    
    SELECT COUNT(*) INTO v_audit_count_after FROM audit_log WHERE table_name = 'account';
    
    IF v_audit_count_after > v_audit_count_before THEN
        RAISE NOTICE '✓ تست 1: تغییر موجودی در Audit ثبت شد';
    ELSE
        RAISE EXCEPTION 'تست 1 شکست خورد!';
    END IF;
END $$;

-- تست 2: وضعیت کارت
DO $$
BEGIN
    UPDATE card 
    SET status = 'BLOCKED' 
    WHERE card_number = '6037991234567890';
    
    IF EXISTS (
        SELECT 1 FROM audit_log 
        WHERE table_name = 'card' 
        AND operation_type = 'UPDATE'
        AND changed_at >= CURRENT_TIMESTAMP - INTERVAL '5 seconds'
    ) THEN
        RAISE NOTICE '✓ تست 2: تغییر وضعیت کارت در Audit ثبت شد';
    ELSE
        RAISE EXCEPTION 'تست 2 شکست خورد!';
    END IF;
    
    -- برگرداندن وضعیت
    UPDATE card SET status = 'ACTIVE' WHERE card_number = '6037991234567890';
END $$;

-- تست 3: درج تراکنش جدید
DO $$
BEGIN
    INSERT INTO transaction (
        transaction_type, amount, description, 
        source_account, destination_account, status
    )
    VALUES (
        'TRANSFER', 50000, 'تست Audit System',
        '1001000100010001', '2002000200020001', 'COMPLETED'
    );
    
    IF EXISTS (
        SELECT 1 FROM audit_log 
        WHERE table_name = 'transaction' 
        AND operation_type = 'INSERT'
        AND changed_at >= CURRENT_TIMESTAMP - INTERVAL '5 seconds'
    ) THEN
        RAISE NOTICE '✓ تست 3: درج تراکنش در Audit ثبت شد';
    ELSE
        RAISE EXCEPTION 'تست 3 شکست خورد!';
    END IF;
END $$;

-- ================================================
-- Query‌های تحلیلی برای Audit
-- ================================================

-- Query 1: آخرین تغییرات در 24 ساعت گذشته
SELECT 
    table_name,
    operation_type,
    COUNT(*) AS change_count,
    MAX(changed_at) AS last_change
FROM audit_log
WHERE changed_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY table_name, operation_type
ORDER BY last_change DESC;

-- Query 2: کاربرانی که بیشترین تغییر را ایجاد کرده‌اند
SELECT 
    changed_by,
    COUNT(*) AS total_changes,
    COUNT(DISTINCT table_name) AS tables_affected,
    MIN(changed_at) AS first_activity,
    MAX(changed_at) AS last_activity
FROM audit_log
GROUP BY changed_by
ORDER BY total_changes DESC;

-- Query 3: حساب‌هایی که موجودی‌شان تغییر کرده
SELECT 
    (new_values->>'account_number') AS account_number,
    COUNT(*) AS change_count,
    SUM((new_values->>'balance')::NUMERIC - (old_values->>'balance')::NUMERIC) AS total_change
FROM audit_log
WHERE table_name = 'account'
  AND operation_type = 'UPDATE'
  AND old_values->>'balance' IS NOT NULL
GROUP BY (new_values->>'account_number')
ORDER BY change_count DESC;

-- ================================================
-- Function برای پاکسازی Audit قدیمی
-- ================================================

CREATE OR REPLACE FUNCTION fn_cleanup_old_audit_logs(days_to_keep INTEGER DEFAULT 365)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM audit_log
    WHERE changed_at < CURRENT_TIMESTAMP - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'پاکسازی Audit: % رکورد قدیمی‌تر از % روز حذف شد', 
                 v_deleted_count, days_to_keep;
    
    RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION fn_cleanup_old_audit_logs IS 
'پاکسازی لاگ‌های قدیمی - به صورت پیش‌فرض رکوردهای بیش از 1 سال را حذف می‌کند';

-- ================================================
-- Procedure برای گزارش Audit
-- ================================================

CREATE OR REPLACE PROCEDURE pr_audit_report(
    p_table_name VARCHAR(50) DEFAULT NULL,
    p_days_back INTEGER DEFAULT 7
)
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE '           گزارش Audit Log';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'بازه زمانی: % روز گذشته', p_days_back;
    IF p_table_name IS NOT NULL THEN
        RAISE NOTICE 'جدول: %', p_table_name;
    ELSE
        RAISE NOTICE 'جدول: همه جداول';
    END IF;
    RAISE NOTICE '================================================';
    
    -- نمایش آمار
    FOR r IN (
        SELECT 
            table_name,
            operation_type,
            COUNT(*) AS count,
            MAX(changed_at) AS last_change
        FROM audit_log
        WHERE changed_at >= CURRENT_TIMESTAMP - (p_days_back || ' days')::INTERVAL
          AND (p_table_name IS NULL OR table_name = p_table_name)
        GROUP BY table_name, operation_type
        ORDER BY table_name, operation_type
    ) LOOP
        RAISE NOTICE '% - %: % عملیات (آخرین: %)', 
                     r.table_name, r.operation_type, r.count, r.last_change;
    END LOOP;
    
    RAISE NOTICE '================================================';
END;
$$;

COMMENT ON PROCEDURE pr_audit_report IS 
'ایجاد گزارش خلاصه از Audit Log';

-- تست گزارش
CALL pr_audit_report(NULL, 1);

-- ================================================
-- نمایش نتیجه نهایی
-- ================================================

DO $$
DECLARE
    v_total_audits INTEGER;
    v_tables_with_audit INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_audits FROM audit_log;
    SELECT COUNT(DISTINCT table_name) INTO v_tables_with_audit FROM audit_log;
    
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '      سیستم Audit با موفقیت راه‌اندازی شد';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'اجزای پیاده‌سازی شده:';
    RAISE NOTICE '  ✓ جدول audit_log برای ذخیره لاگ‌ها';
    RAISE NOTICE '  ✓ Function fn_audit_trigger برای ثبت خودکار';
    RAISE NOTICE '  ✓ Trigger برای 6 جدول حساس';
    RAISE NOTICE '  ✓ 3 View برای تحلیل و گزارش‌گیری';
    RAISE NOTICE '  ✓ Function پاکسازی لاگ‌های قدیمی';
    RAISE NOTICE '  ✓ Procedure گزارش‌گیری';
    RAISE NOTICE '';
    RAISE NOTICE 'آمار فعلی:';
    RAISE NOTICE '  - تعداد کل رخدادهای ثبت شده: %', v_total_audits;
    RAISE NOTICE '  - تعداد جداول تحت نظارت: %', v_tables_with_audit;
    RAISE NOTICE '';
    RAISE NOTICE 'قابلیت‌ها:';
    RAISE NOTICE '  • ثبت خودکار INSERT, UPDATE, DELETE';
    RAISE NOTICE '  • ذخیره مقادیر قبل و بعد (JSON)';
    RAISE NOTICE '  • ثبت کاربر و زمان تغییر';
    RAISE NOTICE '  • ثبت IP و نام برنامه';
    RAISE NOTICE '  • گزارش‌گیری و تحلیل آسان';
    RAISE NOTICE '  • پاکسازی خودکار لاگ‌های قدیمی';
    RAISE NOTICE '';
    RAISE NOTICE 'نحوه استفاده:';
    RAISE NOTICE '  1. SELECT * FROM vw_audit_account_changes LIMIT 10;';
    RAISE NOTICE '  2. CALL pr_audit_report(''account'', 7);';
    RAISE NOTICE '  3. SELECT * FROM vw_audit_statistics;';
    RAISE NOTICE '  4. SELECT fn_cleanup_old_audit_logs(365);';
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '        Phase 9 با موفقیت تکمیل شد!';
    RAISE NOTICE '================================================';
END $$;