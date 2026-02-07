DROP INDEX IF EXISTS idx_transaction_date;
DROP INDEX IF EXISTS idx_branch_city_street;
DROP INDEX IF EXISTS idx_account_balance;
DROP INDEX IF EXISTS idx_active_accounts_balance;

CREATE INDEX idx_transaction_date ON transactions(transaction_date DESC);

-- EXPLAIN ANALYZE
-- SELECT * FROM transactions 
-- WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
-- ORDER BY transaction_date DESC;

--================================================================
CREATE INDEX idx_branch_city_street ON branch(city,street);

-- EXPLAIN ANALYZE
-- SELECT b.*
-- FROM branch b
-- WHERE b.city = 'تهران' and b.street = 'خیابان ولیعصر';

--================================================================
--هزینه زیاد
-- CREATE INDEX idx_employee_salary ON employee(salary);

-- EXPLAIN ANALYZE
-- SELECT e.*
-- FROM employee e
-- WHERE e.salary >30000000;

--================================================================
CREATE INDEX idx_account_balance ON account(balance);

-- EXPLAIN ANALYZE
-- SELECT a.*
-- FROM account a
-- WHERE a.balance >200000;
--================================================================
CREATE INDEX idx_active_accounts_balance ON account(balance DESC) 
WHERE status = 'ACTIVE';

-- EXPLAIN ANALYZE
-- SELECT * FROM account 
-- WHERE status = 'ACTIVE' 
--   AND balance > 10000000
-- ORDER BY balance DESC;
-- --================================================================
-- --این کلید یونیکه  ولی گفتم شاید استفاده شه
-- CREATE INDEX idx_customer_national_id ON customer(national_id);

-- EXPLAIN ANALYZE
-- SELECT * FROM customer WHERE national_id = '1234567890';

--================================================================
--اینم تنوع نداره زیاد ولی برای فیلتر زیاد استفاده میشه
-- CREATE INDEX idx_card_status ON card(status);

-- EXPLAIN ANALYZE
-- SELECT * FROM card 
-- WHERE status = 'ACTIVE';

-- --================================================================

-- CREATE INDEX idx_account_status ON account(status);

-- EXPLAIN ANALYZE
-- SELECT * FROM account  
-- WHERE status = 'ACTIVE';

