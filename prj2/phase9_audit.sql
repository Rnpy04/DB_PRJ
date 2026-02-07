DROP TRIGGER IF EXISTS trg_audit_account ON account;
DROP TRIGGER IF EXISTS trg_audit_transaction ON transactions;
DROP FUNCTION IF EXISTS fn_audit_trigger();
DROP VIEW IF EXISTS vw_audit_account_changes;
DROP VIEW IF EXISTS vw_audit_statistics;
DROP INDEX IF EXISTS idx_audit_table_name;
DROP INDEX IF EXISTS idx_audit_changed_at;
DROP INDEX IF EXISTS idx_audit_changed_by;
DROP INDEX IF EXISTS idx_audit_operation;
DROP TABLE IF EXISTS audit_log CASCADE;

---------------------------------------------------------------------------------------------------

CREATE TABLE audit_log (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation_type VARCHAR(10) NOT NULL,
    record_id VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_operation CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

--خودم ایندکس گذاشتم شاید به کار بیاد
CREATE INDEX idx_audit_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_changed_at ON audit_log(changed_at DESC);
CREATE INDEX idx_audit_changed_by ON audit_log(changed_by);
CREATE INDEX idx_audit_operation ON audit_log(operation_type);

---------------------------------------------------------------------------------------------------

--فانکشن برای ثبت
--تابع عمومی برای همه
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_data JSONB;--برای انعطاف بیشتر با این نوع داده
    v_new_data JSONB;
BEGIN
    --تشخیص نوع عملیات
    IF (TG_OP = 'DELETE') THEN
        v_old_data := row_to_json(OLD)::JSONB;
        v_new_data := NULL;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_old_data := row_to_json(OLD)::JSONB;
        v_new_data := row_to_json(NEW)::JSONB;
    ELSIF (TG_OP = 'INSERT') THEN
        v_old_data := NULL;
        v_new_data := row_to_json(NEW)::JSONB;
    END IF;

    INSERT INTO audit_log (
        table_name,
        operation_type,
        record_id,
        old_values,
        new_values,
        changed_by,
        changed_at,
        -- client_ip,        
        -- application_name  
    )
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        LEFT(
        COALESCE(row_to_json(NEW)::TEXT, row_to_json(OLD)::TEXT),
        50
        ),
        v_old_data,
        v_new_data,
        CURRENT_USER,
        CURRENT_TIMESTAMP,
        -- inet_client_addr(),           
        -- current_setting('application_name')
    );

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

--گفته بود حداقل دو جدول
CREATE TRIGGER trg_audit_account
AFTER INSERT OR UPDATE OR DELETE ON account
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

--برای امنیت بیشتر ..با اینکه خود تراکنش نوعی لاگ است ولی یکی ممکنه پاک کنه تراکنش انجام شده رو
CREATE TRIGGER trg_audit_transaction
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

---------------------------------------------------------------------------------------------------

--ویو ها

-- تغییرات اخیر حساب‌ها
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
  AND operation_type <> 'DELETE'
ORDER BY changed_at DESC;

-- آمار کلی Audit
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

---------------------------------------------------------------------------------------------------

--تست ها
-- تغییر موجودی حساب
-- DO $$
-- DECLARE
--     v_audit_count_before INTEGER;
--     v_audit_count_after INTEGER;
-- BEGIN
--     SELECT COUNT(*) INTO v_audit_count_before FROM audit_log WHERE table_name = 'account';
    
--     UPDATE account 
--     SET balance = balance + 100000 
--     WHERE account_number = '1001000100010001';
    
--     SELECT COUNT(*) INTO v_audit_count_after FROM audit_log WHERE table_name = 'account';
    
--     IF v_audit_count_after > v_audit_count_before THEN
--         RAISE NOTICE 'تغییر موجودی ثبت شد';
--     ELSE
--         RAISE EXCEPTION 'تست موجودی شکست خورد';
--     END IF;
-- END $$;

-- درج تراکنش جدید
-- DO $$
-- BEGIN
--     INSERT INTO transactions (
--         transaction_type, amount, description, 
--         source_account, destination_account, status
--     )
--     VALUES (
--         'TRANSFER', 50000, 'تست Audit System',
--         '1001000100010001', '2002000200020001', 'COMPLETED'
--     );
    
--     IF EXISTS (
--         SELECT 1 FROM audit_log 
--         WHERE table_name = 'transactions' 
--         AND operation_type = 'INSERT'
--         AND changed_at >= CURRENT_TIMESTAMP - INTERVAL '5 seconds'
--     ) THEN
--         RAISE NOTICE 'تراکنش ثبت شد';
--     ELSE
--         RAISE EXCEPTION 'تست تراکنش شکست خورد';
--     END IF;
-- END $$;

---------------------------------------------------------------------------------------------------
