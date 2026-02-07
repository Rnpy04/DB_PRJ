DROP PROCEDURE IF EXISTS pr_transfer_funds(VARCHAR, VARCHAR, DECIMAL, TEXT);
DROP PROCEDURE IF EXISTS pr_pay_bill(VARCHAR, VARCHAR, DECIMAL, VARCHAR, TEXT);
DROP PROCEDURE IF EXISTS pr_register_loan(INTEGER, VARCHAR, DECIMAL, VARCHAR, DECIMAL, INTEGER);

--انتقال وجه بین دو حساب 
CREATE OR REPLACE PROCEDURE pr_transfer_funds(
    --parameter--کاربر وارد
    p_src VARCHAR(16),
    p_dest VARCHAR(16),
    p_amount DECIMAL(15, 2),
    p_description TEXT DEFAULT 'انتقال وجه'
)
LANGUAGE plpgsql
AS $$
DECLARE
    --variable--داخل پروسیجر تعریف فقط در اجرای این استفاده
    v_src_balance DECIMAL(15, 2);
    v_src_status VARCHAR(10);
    v_dest_status VARCHAR(10);
BEGIN
    --بررسی مبلغ 
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ انتقال باید بزرگتر از صفر باشد';
    END IF;

    -------------------------------------------
    -- بررسی حساب‌ها 
    IF p_src = p_dest THEN
        RAISE EXCEPTION 'حساب مبدا و مقصد نمی‌توانند یکسان باشند';
    END IF;
    --مبدا
    SELECT balance, status INTO v_src_balance, v_src_status
    FROM account
    WHERE account_number = p_src;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب مبدا یافت نشد';
    END IF;

    IF v_src_balance < p_amount THEN
        RAISE EXCEPTION 'موجودی ناکافی';
    END IF;
    IF v_src_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب مبدا غیرفعال است. وضعیت: %', v_src_status;
    END IF;
    --مقصد
    SELECT status INTO v_dest_status
    FROM account
    WHERE account_number = p_dest;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب مقصد یافت نشد';
    END IF;

    IF v_dest_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب مقصد غیرفعال است. وضعیت: %', v_dest_status;
    END IF;

    -- انتقال
    -- کسر از حساب مبدا
    UPDATE account
    SET balance = balance - p_amount
    WHERE account_number = p_src;

    -- افزودن به حساب مقصد
    UPDATE account
    SET balance = balance + p_amount
    WHERE account_number = p_dest;

    -- ثبت تراکنش
    INSERT INTO transactions (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('TRANSFER', p_amount, p_description, p_src, p_dest, 'COMPLETED');

    RAISE NOTICE 'انتقال وجه با موفقیت انجام شد. مبلغ: % از % به %', p_amount, p_src, p_dest;
END;
$$;

--------------------------------------------------------------
--پرداخت قبض

CREATE OR REPLACE PROCEDURE pr_pay_bill(
    p_account_number VARCHAR(16),
    p_payment_type VARCHAR(30),
    p_amount DECIMAL(15, 2),
    p_bill_number VARCHAR(20),
    p_description TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance DECIMAL(15, 2);
    v_status VARCHAR(10);
    v_payment_id INTEGER;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ پرداخت باید بزرگتر از صفر ';
    END IF;

    IF p_payment_type NOT IN ('ELECTRICITY', 'WATER', 'GAS', 'PHONE', 'INTERNET', 'INSURANCE', 'TAX', 'OTHER') THEN
        RAISE EXCEPTION 'نوع پرداخت نامعتبر';
    END IF;

    -- حساب
    SELECT balance, status INTO v_balance, v_status
    FROM account
    WHERE account_number = p_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب یافت نشد';
    END IF;

    IF v_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب غیرفعال است';
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'موجودی ناکافی. موجودی فعلی: %، مبلغ قبض: %',  v_balance, p_amount;
    END IF;

    --پرداخت
    --کسر
    UPDATE account
    SET balance = balance - p_amount
    WHERE account_number = p_account_number;

    -- ثبت پرداخت
    INSERT INTO payment (payment_type, amount, bill_number, status, description, account_number)
    VALUES (p_payment_type, p_amount, p_bill_number, 'COMPLETED', p_description, p_account_number)
    RETURNING payment_id INTO v_payment_id;

    -- ثبت تراکنش
    INSERT INTO transactions (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('PAYMENT', p_amount,'پرداخت قبض ' || p_payment_type || ' :شماره: ' || p_bill_number, 
            p_account_number, NULL, 'COMPLETED');

    RAISE NOTICE 'قبض با موفقیت پرداخت شد. شناسه پرداخت: %، مبلغ: %', v_payment_id, p_amount;
END;
$$;

--ثبت وام جدید

CREATE OR REPLACE PROCEDURE pr_register_loan(
    p_customer_id INTEGER,
    p_account_number VARCHAR(16),
    p_loan_amount DECIMAL(15, 2),
    p_loan_type VARCHAR(30),
    p_interest_rate DECIMAL(5, 2),
    p_duration_months INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_exists BOOLEAN;
    v_account_customer_id INTEGER;
    v_account_status VARCHAR(10);
    v_end_date DATE;
    v_loan_id INTEGER;
BEGIN
    IF p_loan_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ وام باید بزرگتر از صفر ';
    END IF;

    -- IF p_interest_rate < 0 OR p_interest_rate > 50 THEN
    --     RAISE EXCEPTION 'نرخ بهره باید بین 0 تا 50 درصد ';
    -- END IF;

    IF p_loan_type NOT IN ('PERSONAL', 'HOME', 'CAR', 'EDUCATION', 'BUSINESS') THEN
        RAISE EXCEPTION 'نوع وام نامعتبر';
    END IF;

    SELECT EXISTS(SELECT 1 FROM customer WHERE customer_id = p_customer_id)
    INTO v_customer_exists;

    IF NOT v_customer_exists THEN
        RAISE EXCEPTION 'مشتری یافت نشد';
    END IF;

    SELECT customer_id, status 
    INTO v_account_customer_id, v_account_status
    FROM account
    WHERE account_number = p_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب با شماره % یافت نشد', p_account_number;
    END IF;

    IF v_account_customer_id != p_customer_id THEN
        RAISE EXCEPTION 'حساب % به مشتری % تعلق ندارد', p_account_number, p_customer_id;
    END IF;

    IF v_account_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب غیرفعال است. وضعیت: %', v_account_status;
    END IF;

    v_end_date := CURRENT_DATE + (p_duration_months || ' months')::INTERVAL;

    INSERT INTO loan (
        loan_amount, loan_type, interest_rate, start_date, end_date, 
        status, remaining_amount, customer_id, account_number
    )
    VALUES (
        p_loan_amount, p_loan_type, p_interest_rate, CURRENT_DATE, v_end_date,
        'ACTIVE', p_loan_amount, p_customer_id, p_account_number
    )
    RETURNING loan_id INTO v_loan_id;

    -- واریز به حساب 
    UPDATE account
    SET balance = balance + p_loan_amount
    WHERE account_number = p_account_number;

    -- ثبت تراکنش 
    INSERT INTO transactions (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('DEPOSIT', p_loan_amount,'واریز وام ' || p_loan_type || ': شناسه: ' || v_loan_id, 
            p_account_number, NULL, 'COMPLETED');

    RAISE NOTICE 'وام با موفقیت ثبت شد. شناسه وام: %، مبلغ: %، مدت: % ماه', 
                 v_loan_id, p_loan_amount, p_duration_months;
END;
$$;

-- -- Test 

-- -- تست 1: انتقال وجه موفق
-- DO $$
-- BEGIN
--     CALL pr_transfer_funds('1001000100010001', '2002000200020001', 500000, 'تست انتقال وجه');
--     RAISE NOTICE 'تست 1: انتقال وجه موفق ✓';
-- EXCEPTION
--     WHEN OTHERS THEN
--         RAISE NOTICE 'تست 1: خطا - %', SQLERRM;
-- END $$;

-- -- تست 2: پرداخت قبض موفق
-- DO $$
-- BEGIN
--     CALL pr_pay_bill('1001000100010001', 'ELECTRICITY', 850000, 'ELEC-TEST-001', 'تست پرداخت قبض');
--     RAISE NOTICE 'تست 2: پرداخت قبض موفق ✓';
-- EXCEPTION
--     WHEN OTHERS THEN
--         RAISE NOTICE 'تست 2: خطا - %', SQLERRM;
-- END $$;

-- -- تست 3: ثبت وام موفق
-- DO $$
-- BEGIN
--     CALL pr_register_loan(1, '1001000100010001', 10000000, 'PERSONAL', 20.0, 24);
--     RAISE NOTICE 'تست 3: ثبت وام موفق ✓';
-- EXCEPTION
--     WHEN OTHERS THEN
--         RAISE NOTICE 'تست 3: خطا - %', SQLERRM;
-- END $$;

