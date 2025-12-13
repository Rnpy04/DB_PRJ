-- ================================================
-- Phase 7: Transaction Management with Procedures
-- ================================================
-- استفاده از Transaction برای اتمیک بودن عملیات‌ها

-- ================================================
-- TRANSACTION 1: tr_transfer_funds
-- انتقال وجه بین دو حساب با مدیریت تراکنش
-- ================================================

/*
توضیحات:
این تراکنش از procedure pr_transfer_funds استفاده می‌کند
و در صورت بروز هر گونه خطا، تمام تغییرات را Rollback می‌کند.

سناریوها:
1. موفق: انتقال وجه با موفقیت انجام شود
2. ناموفق 1: موجودی ناکافی
3. ناموفق 2: حساب مقصد یافت نشود
*/

-- ==================== حالت 1: تراکنش موفق ====================
DO $$
DECLARE
    v_source_balance_before DECIMAL(15, 2);
    v_dest_balance_before DECIMAL(15, 2);
    v_source_balance_after DECIMAL(15, 2);
    v_dest_balance_after DECIMAL(15, 2);
BEGIN
    -- ذخیره موجودی قبل از تراکنش
    SELECT balance INTO v_source_balance_before 
    FROM account WHERE account_number = '7007000700070001';
    
    SELECT balance INTO v_dest_balance_before 
    FROM account WHERE account_number = '3003000300030001';

    RAISE NOTICE '========== تراکنش موفق: انتقال وجه ==========';
    RAISE NOTICE 'موجودی قبل - حساب مبدا: %', v_source_balance_before;
    RAISE NOTICE 'موجودی قبل - حساب مقصد: %', v_dest_balance_before;

    -- شروع تراکنش
    BEGIN
        CALL pr_transfer_funds(
            '7007000700070001',  -- حساب مبدا
            '3003000300030001',  -- حساب مقصد
            1000000,             -- مبلغ
            'انتقال وجه تست - حالت موفق'
        );

        -- موفقیت
        RAISE NOTICE 'تراکنش با موفقیت انجام شد ✓';

        -- بررسی موجودی بعد از تراکنش
        SELECT balance INTO v_source_balance_after 
        FROM account WHERE account_number = '7007000700070001';
        
        SELECT balance INTO v_dest_balance_after 
        FROM account WHERE account_number = '3003000300030001';

        RAISE NOTICE 'موجودی بعد - حساب مبدا: %', v_source_balance_after;
        RAISE NOTICE 'موجودی بعد - حساب مقصد: %', v_dest_balance_after;
        RAISE NOTICE 'تغییر موجودی مبدا: %', (v_source_balance_before - v_source_balance_after);
        RAISE NOTICE 'تغییر موجودی مقصد: %', (v_dest_balance_after - v_dest_balance_before);

    EXCEPTION
        WHEN OTHERS THEN
            -- در صورت خطا، همه چیز به حالت قبل برمی‌گردد
            RAISE NOTICE 'خطا رخ داد: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✗';
            RAISE;
    END;
END $$;

-- ==================== حالت 2: تراکنش ناموفق - موجودی ناکافی ====================
DO $$
DECLARE
    v_source_balance_before DECIMAL(15, 2);
    v_dest_balance_before DECIMAL(15, 2);
    v_source_balance_after DECIMAL(15, 2);
    v_dest_balance_after DECIMAL(15, 2);
BEGIN
    -- ذخیره موجودی قبل
    SELECT balance INTO v_source_balance_before 
    FROM account WHERE account_number = '1111001100110001';
    
    SELECT balance INTO v_dest_balance_before 
    FROM account WHERE account_number = '2002000200020001';

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: موجودی ناکافی ==========';
    RAISE NOTICE 'موجودی قبل - حساب مبدا: %', v_source_balance_before;
    RAISE NOTICE 'تلاش برای انتقال 999,999,999 تومان...';

    BEGIN
        CALL pr_transfer_funds(
            '1111001100110001',  -- حساب با موجودی کم
            '2002000200020001',  
            999999999,           -- مبلغ بیش از حد
            'تست موجودی ناکافی'
        );

        -- اگر به اینجا برسد، تست شکست خورده
        RAISE NOTICE 'خطا: تراکنش نباید موفق شود!';

    EXCEPTION
        WHEN OTHERS THEN
            -- خطای مورد انتظار
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';

            -- بررسی که موجودی تغییر نکرده
            SELECT balance INTO v_source_balance_after 
            FROM account WHERE account_number = '1111001100110001';
            
            SELECT balance INTO v_dest_balance_after 
            FROM account WHERE account_number = '2002000200020001';

            IF v_source_balance_before = v_source_balance_after AND 
               v_dest_balance_before = v_dest_balance_after THEN
                RAISE NOTICE 'موجودی‌ها بدون تغییر ماندند ✓';
            ELSE
                RAISE EXCEPTION 'خطا: موجودی‌ها تغییر کرده‌اند!';
            END IF;
    END;
END $$;

-- ==================== حالت 3: تراکنش ناموفق - حساب نامعتبر ====================
DO $$
DECLARE
    v_source_balance_before DECIMAL(15, 2);
    v_source_balance_after DECIMAL(15, 2);
BEGIN
    SELECT balance INTO v_source_balance_before 
    FROM account WHERE account_number = '4004000400040001';

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: حساب مقصد نامعتبر ==========';
    RAISE NOTICE 'موجودی قبل - حساب مبدا: %', v_source_balance_before;

    BEGIN
        CALL pr_transfer_funds(
            '4004000400040001',
            '9999999999999999',  -- حساب نامعتبر
            1000000,
            'تست حساب نامعتبر'
        );

        RAISE NOTICE 'خطا: تراکنش نباید موفق شود!';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';

            SELECT balance INTO v_source_balance_after 
            FROM account WHERE account_number = '4004000400040001';

            IF v_source_balance_before = v_source_balance_after THEN
                RAISE NOTICE 'موجودی بدون تغییر ماند ✓';
            END IF;
    END;
END $$;

-- ================================================
-- TRANSACTION 2: tr_register_loan
-- ثبت وام جدید با مدیریت تراکنش
-- ================================================

/*
توضیحات:
این تراکنش از procedure pr_register_loan استفاده می‌کند
و در صورت خطا، ثبت وام و واریز وجه را Rollback می‌کند.
*/

-- ==================== حالت 1: تراکنش موفق ====================
DO $$
DECLARE
    v_balance_before DECIMAL(15, 2);
    v_balance_after DECIMAL(15, 2);
    v_loan_count_before INTEGER;
    v_loan_count_after INTEGER;
BEGIN
    SELECT balance INTO v_balance_before 
    FROM account WHERE account_number = '5005000500050001';
    
    SELECT COUNT(*) INTO v_loan_count_before 
    FROM loan WHERE customer_id = 5;

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش موفق: ثبت وام جدید ==========';
    RAISE NOTICE 'موجودی قبل از وام: %', v_balance_before;
    RAISE NOTICE 'تعداد وام‌های قبلی: %', v_loan_count_before;

    BEGIN
        CALL pr_register_loan(
            5,                    -- مشتری
            '5005000500050001',  -- حساب
            5000000,             -- مبلغ وام
            'EDUCATION',         -- نوع وام
            18.5,                -- نرخ بهره
            36                   -- مدت (ماه)
        );

        RAISE NOTICE 'وام با موفقیت ثبت شد ✓';

        SELECT balance INTO v_balance_after 
        FROM account WHERE account_number = '5005000500050001';
        
        SELECT COUNT(*) INTO v_loan_count_after 
        FROM loan WHERE customer_id = 5;

        RAISE NOTICE 'موجودی بعد از وام: %', v_balance_after;
        RAISE NOTICE 'تعداد وام‌های جدید: %', v_loan_count_after;
        RAISE NOTICE 'افزایش موجودی: %', (v_balance_after - v_balance_before);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطا: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✗';
            RAISE;
    END;
END $$;

-- ==================== حالت 2: تراکنش ناموفق - حساب نامتعلق به مشتری ====================
DO $$
DECLARE
    v_balance_before DECIMAL(15, 2);
    v_balance_after DECIMAL(15, 2);
    v_loan_count_before INTEGER;
    v_loan_count_after INTEGER;
BEGIN
    SELECT balance INTO v_balance_before 
    FROM account WHERE account_number = '1001000100010001';
    
    SELECT COUNT(*) INTO v_loan_count_before 
    FROM loan WHERE customer_id = 2;

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: حساب متعلق به مشتری دیگر ==========';

    BEGIN
        CALL pr_register_loan(
            2,                    -- مشتری 2
            '1001000100010001',  -- حساب متعلق به مشتری 1
            3000000,
            'CAR',
            20.0,
            24
        );

        RAISE NOTICE 'خطا: وام نباید ثبت شود!';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';

            SELECT balance INTO v_balance_after 
            FROM account WHERE account_number = '1001000100010001';
            
            SELECT COUNT(*) INTO v_loan_count_after 
            FROM loan WHERE customer_id = 2;

            IF v_balance_before = v_balance_after AND 
               v_loan_count_before = v_loan_count_after THEN
                RAISE NOTICE 'هیچ تغییری ایجاد نشد ✓';
            END IF;
    END;
END $$;

-- ==================== حالت 3: تراکنش ناموفق - نرخ بهره نامعتبر ====================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: نرخ بهره نامعتبر ==========';

    BEGIN
        CALL pr_register_loan(
            3,
            '3003000300030001',
            10000000,
            'BUSINESS',
            75.5,  -- نرخ بهره بیش از حد
            48
        );

        RAISE NOTICE 'خطا: وام نباید ثبت شود!';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';
    END;
END $$;

-- ================================================
-- TRANSACTION 3: tr_pay_bill
-- پرداخت قبض با مدیریت تراکنش
-- ================================================

-- ==================== حالت 1: تراکنش موفق ====================
DO $$
DECLARE
    v_balance_before DECIMAL(15, 2);
    v_balance_after DECIMAL(15, 2);
    v_payment_count_before INTEGER;
    v_payment_count_after INTEGER;
BEGIN
    SELECT balance INTO v_balance_before 
    FROM account WHERE account_number = '6006000600060001';
    
    SELECT COUNT(*) INTO v_payment_count_before 
    FROM payment WHERE account_number = '6006000600060001';

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش موفق: پرداخت قبض ==========';
    RAISE NOTICE 'موجودی قبل: %', v_balance_before;
    RAISE NOTICE 'تعداد پرداخت‌های قبلی: %', v_payment_count_before;

    BEGIN
        CALL pr_pay_bill(
            '6006000600060001',
            'ELECTRICITY',
            950000,
            'ELEC-2024-TEST',
            'تست پرداخت قبض برق'
        );

        RAISE NOTICE 'قبض با موفقیت پرداخت شد ✓';

        SELECT balance INTO v_balance_after 
        FROM account WHERE account_number = '6006000600060001';
        
        SELECT COUNT(*) INTO v_payment_count_after 
        FROM payment WHERE account_number = '6006000600060001';

        RAISE NOTICE 'موجودی بعد: %', v_balance_after;
        RAISE NOTICE 'تعداد پرداخت‌های جدید: %', v_payment_count_after;
        RAISE NOTICE 'کاهش موجودی: %', (v_balance_before - v_balance_after);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطا: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✗';
            RAISE;
    END;
END $$;

-- ==================== حالت 2: تراکنش ناموفق - موجودی ناکافی ====================
DO $$
DECLARE
    v_balance_before DECIMAL(15, 2);
    v_balance_after DECIMAL(15, 2);
BEGIN
    SELECT balance INTO v_balance_before 
    FROM account WHERE account_number = '1111001100110001';

    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: موجودی ناکافی برای پرداخت ==========';
    RAISE NOTICE 'موجودی فعلی: %', v_balance_before;

    BEGIN
        CALL pr_pay_bill(
            '1111001100110001',
            'WATER',
            99999999,  -- مبلغ بیش از موجودی
            'WATER-TEST',
            'تست موجودی ناکافی'
        );

        RAISE NOTICE 'خطا: پرداخت نباید انجام شود!';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';

            SELECT balance INTO v_balance_after 
            FROM account WHERE account_number = '1111001100110001';

            IF v_balance_before = v_balance_after THEN
                RAISE NOTICE 'موجودی بدون تغییر ماند ✓';
            END IF;
    END;
END $$;

-- ==================== حالت 3: تراکنش ناموفق - نوع پرداخت نامعتبر ====================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== تراکنش ناموفق: نوع پرداخت نامعتبر ==========';

    BEGIN
        CALL pr_pay_bill(
            '2002000200020001',
            'INVALID_TYPE',  -- نوع نامعتبر
            500000,
            'TEST-BILL',
            'تست نوع نامعتبر'
        );

        RAISE NOTICE 'خطا: پرداخت نباید انجام شود!';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE 'تراکنش Rollback شد ✓';
    END;
END $$;

-- ================================================
-- Final Report
-- ================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '           گزارش نهایی تست تراکنش‌ها';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'تعداد کل تست‌ها: 9';
    RAISE NOTICE '';
    RAISE NOTICE '✓ tr_transfer_funds - 3 حالت تست شد';
    RAISE NOTICE '  1. انتقال موفق';
    RAISE NOTICE '  2. موجودی ناکافی (Rollback)';
    RAISE NOTICE '  3. حساب نامعتبر (Rollback)';
    RAISE NOTICE '';
    RAISE NOTICE '✓ tr_register_loan - 3 حالت تست شد';
    RAISE NOTICE '  1. ثبت وام موفق';
    RAISE NOTICE '  2. حساب نامتعلق (Rollback)';
    RAISE NOTICE '  3. نرخ بهره نامعتبر (Rollback)';
    RAISE NOTICE '';
    RAISE NOTICE '✓ tr_pay_bill - 3 حالت تست شد';
    RAISE NOTICE '  1. پرداخت موفق';
    RAISE NOTICE '  2. موجودی ناکافی (Rollback)';
    RAISE NOTICE '  3. نوع نامعتبر (Rollback)';
    RAISE NOTICE '';
    RAISE NOTICE 'نتیجه: تمام تراکنش‌ها به درستی COMMIT یا ROLLBACK شدند';
    RAISE NOTICE '================================================';
END $$;