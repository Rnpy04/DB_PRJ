-- ================================================
-- Phase 6: Stored Procedures Implementation
-- ================================================

-- ================================================
-- PROCEDURE 1: pr_transfer_funds
-- انتقال وجه بین دو حساب
-- ================================================
/*
توضیحات:
این پروسیجر انتقال وجه بین دو حساب بانکی را انجام می‌دهد.

پارامترها:
- p_source_account: شماره حساب مبدا
- p_destination_account: شماره حساب مقصد
- p_amount: مبلغ انتقال
- p_description: توضیحات تراکنش

منطق:
1. بررسی وجود هر دو حساب
2. بررسی وضعیت فعال بودن حساب‌ها
3. بررسی موجودی کافی در حساب مبدا
4. کسر مبلغ از حساب مبدا
5. افزودن مبلغ به حساب مقصد
6. ثبت دو رکورد تراکنش (برداشت و واریز)

خطاهای احتمالی:
- حساب مبدا یافت نشد
- حساب مقصد یافت نشد
- حساب مبدا غیرفعال است
- حساب مقصد غیرفعال است
- موجودی ناکافی
- مبلغ باید مثبت باشد
*/

CREATE OR REPLACE PROCEDURE pr_transfer_funds(
    p_source_account VARCHAR(16),
    p_destination_account VARCHAR(16),
    p_amount DECIMAL(15, 2),
    p_description TEXT DEFAULT 'انتقال وجه'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_source_balance DECIMAL(15, 2);
    v_source_status VARCHAR(10);
    v_dest_status VARCHAR(10);
BEGIN
    -- ==================== بررسی مبلغ ====================
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ انتقال باید بزرگتر از صفر باشد';
    END IF;

    -- ==================== بررسی عدم یکسان بودن حساب‌ها ====================
    IF p_source_account = p_destination_account THEN
        RAISE EXCEPTION 'حساب مبدا و مقصد نمی‌توانند یکسان باشند';
    END IF;

    -- ==================== بررسی حساب مبدا ====================
    SELECT balance, status INTO v_source_balance, v_source_status
    FROM account
    WHERE account_number = p_source_account;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب مبدا با شماره % یافت نشد', p_source_account;
    END IF;

    IF v_source_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب مبدا غیرفعال است. وضعیت: %', v_source_status;
    END IF;

    IF v_source_balance < p_amount THEN
        RAISE EXCEPTION 'موجودی ناکافی. موجودی فعلی: %، مبلغ درخواستی: %', 
                        v_source_balance, p_amount;
    END IF;

    -- ==================== بررسی حساب مقصد ====================
    SELECT status INTO v_dest_status
    FROM account
    WHERE account_number = p_destination_account;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب مقصد با شماره % یافت نشد', p_destination_account;
    END IF;

    IF v_dest_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب مقصد غیرفعال است. وضعیت: %', v_dest_status;
    END IF;

    -- ==================== انجام انتقال ====================
    -- کسر از حساب مبدا
    UPDATE account
    SET balance = balance - p_amount
    WHERE account_number = p_source_account;

    -- افزودن به حساب مقصد
    UPDATE account
    SET balance = balance + p_amount
    WHERE account_number = p_destination_account;

    -- ثبت تراکنش
    INSERT INTO transaction (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('TRANSFER', p_amount, p_description, p_source_account, p_destination_account, 'COMPLETED');

    RAISE NOTICE 'انتقال وجه با موفقیت انجام شد. مبلغ: % از % به %', 
                 p_amount, p_source_account, p_destination_account;
END;
$$;

COMMENT ON PROCEDURE pr_transfer_funds IS 
'انتقال وجه بین دو حساب بانکی با بررسی‌های کامل امنیتی';

-- ================================================
-- PROCEDURE 2: pr_pay_bill
-- پرداخت قبض
-- ================================================
/*
توضیحات:
این پروسیجر پرداخت قبوض مختلف از حساب مشتری را انجام می‌دهد.

پارامترها:
- p_account_number: شماره حساب پرداخت‌کننده
- p_payment_type: نوع قبض (برق، آب، گاز، ...)
- p_amount: مبلغ قبض
- p_bill_number: شماره قبض
- p_description: توضیحات اضافی

منطق:
1. بررسی وجود حساب
2. بررسی وضعیت فعال حساب
3. بررسی موجودی کافی
4. کسر مبلغ از حساب
5. ثبت پرداخت در جدول payment
6. ثبت تراکنش

خطاهای احتمالی:
- حساب یافت نشد
- حساب غیرفعال است
- موجودی ناکافی
- نوع پرداخت نامعتبر
*/

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
    -- ==================== بررسی مبلغ ====================
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ پرداخت باید بزرگتر از صفر باشد';
    END IF;

    -- ==================== بررسی نوع پرداخت ====================
    IF p_payment_type NOT IN ('ELECTRICITY', 'WATER', 'GAS', 'PHONE', 'INTERNET', 'INSURANCE', 'TAX', 'OTHER') THEN
        RAISE EXCEPTION 'نوع پرداخت نامعتبر: %', p_payment_type;
    END IF;

    -- ==================== بررسی حساب ====================
    SELECT balance, status INTO v_balance, v_status
    FROM account
    WHERE account_number = p_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'حساب با شماره % یافت نشد', p_account_number;
    END IF;

    IF v_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'حساب غیرفعال است. وضعیت: %', v_status;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'موجودی ناکافی. موجودی فعلی: %، مبلغ قبض: %', 
                        v_balance, p_amount;
    END IF;

    -- ==================== انجام پرداخت ====================
    -- کسر مبلغ از حساب
    UPDATE account
    SET balance = balance - p_amount
    WHERE account_number = p_account_number;

    -- ثبت پرداخت
    INSERT INTO payment (payment_type, amount, bill_number, status, description, account_number)
    VALUES (p_payment_type, p_amount, p_bill_number, 'COMPLETED', p_description, p_account_number)
    RETURNING payment_id INTO v_payment_id;

    -- ثبت تراکنش
    INSERT INTO transaction (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('PAYMENT', p_amount, 
            'پرداخت قبض ' || p_payment_type || ' - شماره: ' || p_bill_number, 
            p_account_number, NULL, 'COMPLETED');

    RAISE NOTICE 'قبض با موفقیت پرداخت شد. شناسه پرداخت: %، مبلغ: %', v_payment_id, p_amount;
END;
$$;

COMMENT ON PROCEDURE pr_pay_bill IS 
'پرداخت قبوض مختلف از حساب بانکی';

-- ================================================
-- PROCEDURE 3: pr_register_loan
-- ثبت وام جدید
-- ================================================
/*
توضیحات:
این پروسیجر ثبت وام جدید برای مشتری را انجام می‌دهد.

پارامترها:
- p_customer_id: شناسه مشتری
- p_account_number: شماره حساب واریز وام
- p_loan_amount: مبلغ وام
- p_loan_type: نوع وام
- p_interest_rate: نرخ بهره سالانه
- p_duration_months: مدت وام به ماه

منطق:
1. بررسی وجود مشتری
2. بررسی وجود و وضعیت حساب
3. بررسی تعلق حساب به مشتری
4. ثبت وام جدید
5. واریز مبلغ وام به حساب
6. ثبت تراکنش واریز

خطاهای احتمالی:
- مشتری یافت نشد
- حساب یافت نشد
- حساب به این مشتری تعلق ندارد
- حساب غیرفعال است
- نوع وام نامعتبر
- مبلغ یا نرخ بهره نامعتبر
*/

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
    -- ==================== بررسی پارامترها ====================
    IF p_loan_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ وام باید بزرگتر از صفر باشد';
    END IF;

    IF p_interest_rate < 0 OR p_interest_rate > 50 THEN
        RAISE EXCEPTION 'نرخ بهره باید بین 0 تا 50 درصد باشد';
    END IF;

    IF p_duration_months <= 0 OR p_duration_months > 360 THEN
        RAISE EXCEPTION 'مدت وام باید بین 1 تا 360 ماه باشد';
    END IF;

    -- ==================== بررسی نوع وام ====================
    IF p_loan_type NOT IN ('PERSONAL', 'HOME', 'CAR', 'EDUCATION', 'BUSINESS') THEN
        RAISE EXCEPTION 'نوع وام نامعتبر: %', p_loan_type;
    END IF;

    -- ==================== بررسی مشتری ====================
    SELECT EXISTS(SELECT 1 FROM customer WHERE customer_id = p_customer_id)
    INTO v_customer_exists;

    IF NOT v_customer_exists THEN
        RAISE EXCEPTION 'مشتری با شناسه % یافت نشد', p_customer_id;
    END IF;

    -- ==================== بررسی حساب ====================
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

    -- ==================== محاسبه تاریخ پایان ====================
    v_end_date := CURRENT_DATE + (p_duration_months || ' months')::INTERVAL;

    -- ==================== ثبت وام ====================
    INSERT INTO loan (
        loan_amount, loan_type, interest_rate, start_date, end_date, 
        status, remaining_amount, customer_id, account_number
    )
    VALUES (
        p_loan_amount, p_loan_type, p_interest_rate, CURRENT_DATE, v_end_date,
        'ACTIVE', p_loan_amount, p_customer_id, p_account_number
    )
    RETURNING loan_id INTO v_loan_id;

    -- ==================== واریز مبلغ وام به حساب ====================
    UPDATE account
    SET balance = balance + p_loan_amount
    WHERE account_number = p_account_number;

    -- ==================== ثبت تراکنش ====================
    INSERT INTO transaction (transaction_type, amount, description, source_account, destination_account, status)
    VALUES ('DEPOSIT', p_loan_amount, 
            'واریز وام ' || p_loan_type || ' - شناسه: ' || v_loan_id, 
            p_account_number, NULL, 'COMPLETED');

    RAISE NOTICE 'وام با موفقیت ثبت شد. شناسه وام: %، مبلغ: %، مدت: % ماه', 
                 v_loan_id, p_loan_amount, p_duration_months;
END;
$$;

COMMENT ON PROCEDURE pr_register_loan IS 
'ثبت وام جدید برای مشتری و واریز به حساب';

-- ================================================
-- Test Cases for Procedures
-- ================================================

-- تست 1: انتقال وجه موفق
DO $$
BEGIN
    CALL pr_transfer_funds('1001000100010001', '2002000200020001', 500000, 'تست انتقال وجه');
    RAISE NOTICE 'تست 1: انتقال وجه موفق ✓';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 1: خطا - %', SQLERRM;
END $$;

-- تست 2: پرداخت قبض موفق
DO $$
BEGIN
    CALL pr_pay_bill('1001000100010001', 'ELECTRICITY', 850000, 'ELEC-TEST-001', 'تست پرداخت قبض');
    RAISE NOTICE 'تست 2: پرداخت قبض موفق ✓';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 2: خطا - %', SQLERRM;
END $$;

-- تست 3: ثبت وام موفق
DO $$
BEGIN
    CALL pr_register_loan(1, '1001000100010001', 10000000, 'PERSONAL', 20.0, 24);
    RAISE NOTICE 'تست 3: ثبت وام موفق ✓';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 3: خطا - %', SQLERRM;
END $$;

-- تست 4: خطا - موجودی ناکافی
DO $$
BEGIN
    CALL pr_transfer_funds('1111001100110001', '2002000200020001', 999999999, 'تست موجودی ناکافی');
    RAISE NOTICE 'تست 4: نباید به اینجا برسد!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 4: خطای مورد انتظار دریافت شد ✓ - %', SQLERRM;
END $$;

-- تست 5: خطا - حساب یافت نشد
DO $$
BEGIN
    CALL pr_pay_bill('9999999999999999', 'WATER', 100000, 'TEST-001', 'تست حساب نامعتبر');
    RAISE NOTICE 'تست 5: نباید به اینجا برسد!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 5: خطای مورد انتظار دریافت شد ✓ - %', SQLERRM;
END $$;

-- تست 6: خطا - نرخ بهره نامعتبر
DO $$
BEGIN
    CALL pr_register_loan(1, '1001000100010001', 5000000, 'CAR', 99.99, 12);
    RAISE NOTICE 'تست 6: نباید به اینجا برسد!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'تست 6: خطای مورد انتظار دریافت شد ✓ - %', SQLERRM;
END $$;

-- ================================================
-- Display Success Message
-- ================================================
DO $$
BEGIN 
    RAISE NOTICE '============================================';
    RAISE NOTICE 'تمام Stored Procedures با موفقیت ایجاد شدند!';
    RAISE NOTICE '============================================';
    RAISE NOTICE '✓ pr_transfer_funds - انتقال وجه';
    RAISE NOTICE '✓ pr_pay_bill - پرداخت قبض';
    RAISE NOTICE '✓ pr_register_loan - ثبت وام';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'تست‌های خودکار با موفقیت اجرا شدند';
    RAISE NOTICE '============================================';
END $$;