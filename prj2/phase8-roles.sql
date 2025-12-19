DROP ROLE IF EXISTS role_bank_admin;
DROP ROLE IF EXISTS role_branch_employee;

DROP USER IF EXISTS admin_user;
DROP USER IF EXISTS employee_user1;
DROP USER IF EXISTS employee_user2;

--------------------------------------------------------------------------------------------------
CREATE ROLE role_bank_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO role_bank_admin;
-- دسترسی به Sequences (برای AUTO INCREMENT)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO role_bank_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO role_bank_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO role_bank_admin;
-- دسترسی به Views
GRANT SELECT ON ALL TABLES IN SCHEMA public TO role_bank_admin;
-- اعطای دسترسی‌های آینده (برای جداول جدید)
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO role_bank_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT USAGE, SELECT ON SEQUENCES TO role_bank_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO role_bank_admin;

GRANT REFERENCES ON ALL TABLES IN SCHEMA public TO role_bank_admin;
GRANT TRUNCATE ON ALL TABLES IN SCHEMA public TO role_bank_admin;
GRANT USAGE, CREATE ON SCHEMA public TO role_bank_admin;

--------------------------------------------------------------------------------------------------
CREATE ROLE role_branch_employee;
GRANT SELECT ON customer TO role_branch_employee;
GRANT SELECT ON account TO role_branch_employee;
GRANT SELECT ON transactions TO role_branch_employee;
GRANT SELECT ON card TO role_branch_employee;
GRANT SELECT ON loan TO role_branch_employee;
GRANT SELECT ON payment TO role_branch_employee;

GRANT INSERT ON transactions TO role_branch_employee;
GRANT INSERT ON payment TO role_branch_employee;

GRANT UPDATE (status, account_type) ON account TO role_branch_employee;
GRANT UPDATE (phone, address,email) ON customer TO role_branch_employee;
GRANT UPDATE (status) ON card TO role_branch_employee;

GRANT USAGE, SELECT ON SEQUENCE customer_customer_id_seq TO role_branch_employee;
GRANT USAGE, SELECT ON SEQUENCE transactions_transaction_id_seq TO role_branch_employee;
GRANT USAGE, SELECT ON SEQUENCE payment_payment_id_seq TO role_branch_employee;
GRANT USAGE, SELECT ON SEQUENCE loan_loan_id_seq TO role_branch_employee;

-- دسترسی به Views (برای گزارش‌گیری)
GRANT SELECT ON vw_customer_accounts_summary TO role_branch_employee;
GRANT SELECT ON vw_active_loans TO role_branch_employee;
GRANT SELECT ON vw_recent_transactions_30days TO role_branch_employee;
GRANT SELECT ON vw_active_accounts_basic TO role_branch_employee;

-- دسترسی اجرای Procedures (امن)
GRANT EXECUTE ON PROCEDURE pr_transfer_funds TO role_branch_employee;
GRANT EXECUTE ON PROCEDURE pr_pay_bill TO role_branch_employee;
GRANT EXECUTE ON PROCEDURE pr_register_loan TO role_branch_employee;


--------------------------------------------------------------------------------------------------

CREATE USER admin_user WITH PASSWORD 'Admin@20!Secure';
GRANT role_bank_admin TO admin_user;

CREATE USER employee_user1 WITH PASSWORD 'Employee1@20!';
GRANT role_branch_employee TO employee_user1;

CREATE USER employee_user2 WITH PASSWORD 'Employee2@20!';
GRANT role_branch_employee TO employee_user2;
--------------------------------------------------------------------------------------------------

SELECT 
    'role_bank_admin' AS role_name,
    table_name,
    string_agg(privilege_type, ', ') AS privileges
FROM information_schema.role_table_grants
WHERE grantee = 'role_bank_admin'
  AND table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;

SELECT 
    'role_branch_employee' AS role_name,
    table_name,
    string_agg(privilege_type, ', ') AS privileges
FROM information_schema.role_table_grants
WHERE grantee = 'role_branch_employee'
  AND table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;

-- تست 3: لیست تمام نقش‌ها و اعضا
SELECT 
    r.rolname AS role,
    m.rolname AS member
FROM pg_roles r
LEFT JOIN pg_auth_members am ON r.oid = am.roleid
LEFT JOIN pg_roles m ON am.member = m.oid
WHERE r.rolname LIKE 'role_%' OR r.rolname LIKE '%_user%'
ORDER BY r.rolname, m.rolname;
