DROP VIEW IF EXISTS vw_customer_accounts_summary;
DROP VIEW IF EXISTS vw_active_loans;
DROP VIEW IF EXISTS vw_recent_transactions_30days;
DROP VIEW IF EXISTS vw_active_accounts_basic;

--4
CREATE OR REPLACE VIEW vw_active_accounts_basic AS
SELECT
    -- a.account_number,
    a.account_type as account_type,
    a.balance as balance,
    a.status as status,
    a.opening_date as opening_date,

    c.customer_id as customer_id,
    -- c.first_name || ' ' || c.last_name AS customer_name,

    b.branch_code as branch_code,
    b.city AS city 
FROM account a
JOIN customer c ON a.customer_id = c.customer_id
JOIN branch b ON a.branch_code = b.branch_code
WHERE a.status = 'ACTIVE';

--1
-- خلاصه حساب‌های هر مشتری
CREATE OR REPLACE VIEW vw_customer_accounts_summary AS
SELECT 
    customer_id,
    -- c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) AS active_accounts,
    COUNT(CASE WHEN status <> 'ACTIVE' THEN 1 END) AS inactive_accounts,

    SUM(CASE WHEN status = 'ACTIVE' THEN balance ELSE 0 END) AS total_balance,
    MAX(CASE WHEN status = 'ACTIVE' THEN balance ELSE 0 END) AS highest_balance,
    MIN(CASE WHEN status = 'ACTIVE' THEN balance ELSE 0 END) AS lowest_balance,

    MIN(opening_date) AS first_account_date,
    MAX(opening_date) AS latest_account_date,
    MAX(CASE WHEN status = 'ACTIVE' THEN opening_date END) AS latest_account_date_active
FROM vw_active_accounts_basic
GROUP BY customer_id;

-- وام‌های فعال مشتریان
CREATE OR REPLACE VIEW vw_active_loans AS
SELECT 
    l.loan_id,
    l.customer_id,
    -- c.first_name || ' ' || c.last_name AS customer_name,
    l.loan_type,
    l.loan_amount,
    l.remaining_amount,
    CASE 
        WHEN l.loan_amount > 0 
        THEN (l.remaining_amount * 100.0 / l.loan_amount)
        ELSE 0
    END AS remaining_percentage,
    l.interest_rate,
    l.start_date,
    l.end_date,
    l.end_date - CURRENT_DATE AS days_remaining, --اگه منفی شه یعنی گذشته وقتت
    l.account_number
FROM loan l
-- JOIN customer c ON l.customer_id = c.customer_id
-- JOIN account a ON l.account_number = a.account_number
WHERE l.status = 'ACTIVE';

-- تراکنش‌های 30 روز اخیر
CREATE OR REPLACE VIEW vw_recent_transactions_30days AS
SELECT 
    t.transaction_id,
    t.transaction_type,
    CASE 
        WHEN t.amount < 1000000 THEN 'کمتر از 1 میلیون'
        WHEN t.amount < 5000000 THEN '1 تا 5 میلیون'
        WHEN t.amount < 10000000 THEN '5 تا 10 میلیون'
        WHEN t.amount < 50000000 THEN '10 تا 50 میلیون'
        ELSE 'بیش از 50 میلیون'
    END AS amount_range,
    t.transaction_date,
    t.status,
    src.customer_id AS source_customer_id,
    dst.customer_id AS dest_customer_id

FROM transactions t
JOIN account src 
    ON src.account_number = t.source_account
LEFT JOIN account dst 
    ON dst.account_number = t.destination_account    
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  AND t.status = 'COMPLETED';


-- تست 
-- SELECT * FROM vw_customer_accounts_summary  
-- WHERE total_balance > 10000000
-- ORDER BY total_balance DESC;

-- -- تست 
-- SELECT * FROM vw_active_loans 
-- WHERE remaining_percentage > 80
-- ORDER BY remaining_amount DESC;

-- -- تست
-- SELECT *
-- FROM vw_recent_transactions_30days;


-- بررسی ساختار view‌ها
-- SELECT 
--     table_name,
--     view_definition
-- FROM information_schema.views
-- WHERE table_schema = 'public'
--   AND table_name LIKE 'vw_%'
-- ORDER BY table_name;

-- -- تحلیل عملکرد View 1
-- EXPLAIN ANALYZE
-- SELECT * FROM vw_customer_accounts_summary
-- WHERE total_balance > 5000000;

-- -- تحلیل عملکرد View 2
-- EXPLAIN ANALYZE
-- SELECT * FROM vw_active_loans
-- WHERE loan_type = 'HOME';

-- -- تحلیل عملکرد View 3
-- EXPLAIN ANALYZE
-- SELECT * FROM vw_recent_transactions_30days
-- WHERE transaction_type = 'TRANSFER';