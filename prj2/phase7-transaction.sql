
--tr_transfer_funds
-- ==================== حالت 1: تراکنش موفق ====================
-- ==================== حالت 2: تراکنش ناموفق - موجودی ناکافی ====================

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
    -- FROM account WHERE account_number = '1111001100110001';

    SELECT balance INTO v_dest_balance_before 
    FROM account WHERE account_number = '3003000300030001';
    -- FROM account WHERE account_number = '2002000200020001';

    RAISE NOTICE 'موفق';
    RAISE NOTICE ' حساب مبدا: %', v_source_balance_before;
    RAISE NOTICE ' حساب مقصد: %', v_dest_balance_before;


    -- RAISE NOTICE '';
    -- RAISE NOTICE 'ناموفق موجودی کم';
    -- RAISE NOTICE ' حساب مبدا: %', v_source_balance_before;
    -- RAISE NOTICE ' حساب مقصد: %', v_dest_balance_before;


    BEGIN
        CALL pr_transfer_funds(
            '7007000700070001',  --  مبدا
            '3003000300030001',  --  مقصد
            1000000,             -- مبلغ
            'انتقال وجه تست - حالت موفق'
        );
    
        RAISE NOTICE 'تراکنش انجام شد.';

    -- BEGIN
    --     CALL pr_transfer_funds(
    --         '1111001100110001',  
    --         '2002000200020001',  
    --         999999999,           
    --         'تست موجودی ناکافی'
    --     );

    --     RAISE NOTICE 'خطا';



        -- بررسی موجودی بعد
        SELECT balance INTO v_source_balance_after 
        FROM account WHERE account_number = '7007000700070001';
        
        SELECT balance INTO v_dest_balance_after 
        FROM account WHERE account_number = '3003000300030001';

        RAISE NOTICE 'موجودی بعد -  مبدا: %', v_source_balance_after;
        RAISE NOTICE 'موجودی بعد -  مقصد: %', v_dest_balance_after;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطا: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';
            RAISE;

    EXCEPTION
        WHEN OTHERS THEN
            -- خطای مورد انتظار
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';

            SELECT balance INTO v_source_balance_after 
            FROM account WHERE account_number = '1111001100110001';
            
            SELECT balance INTO v_dest_balance_after 
            FROM account WHERE account_number = '2002000200020001';

            IF v_source_balance_before = v_source_balance_after AND 
               v_dest_balance_before = v_dest_balance_after THEN
                RAISE NOTICE 'موجودی‌ها بدون تغییر  ✓';
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

    RAISE NOTICE 'موجودی قبل -  مبدا: %', v_source_balance_before;

    BEGIN
        CALL pr_transfer_funds(
            '4004000400040001',
            '9999999999999999',  -- حساب نامعتبر
            1000000,
            'تست حساب نامعتبر'
        );

        RAISE NOTICE 'خطا';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';

            SELECT balance INTO v_source_balance_after 
            FROM account WHERE account_number = '4004000400040001';

            IF v_source_balance_before = v_source_balance_after THEN
                RAISE NOTICE 'موجودی بدون تغییر  ';
            END IF;
    END;
END $$;

-- ================================================
-- tr_register_loan

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
    RAISE NOTICE 'موجودی قبل: %', v_balance_before;
    RAISE NOTICE 'تعداد وام‌های قبلی: %', v_loan_count_before;

    BEGIN
        CALL pr_register_loan(
            5,                    -- مشتری
            '5005000500050001',  -- حساب
            5000000,             -- مبلغ 
            'EDUCATION',         -- نوع 
            18.5,                -- نرخ بهره
            36                   -- مدت (ماه)
        );

        RAISE NOTICE 'وام ثبت شد';

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
            RAISE NOTICE ' Rollback شد ';
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

    BEGIN
        CALL pr_register_loan(
            2,                    -- مشتری 2
            '1001000100010001',  -- حساب متعلق به مشتری 1
            3000000,
            'CAR',
            20.0,
            24
        );

        RAISE NOTICE 'خطا';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';

            SELECT balance INTO v_balance_after 
            FROM account WHERE account_number = '1001000100010001';
            
            SELECT COUNT(*) INTO v_loan_count_after 
            FROM loan WHERE customer_id = 2;

            IF v_balance_before = v_balance_after AND 
               v_loan_count_before = v_loan_count_after THEN
                RAISE NOTICE ' تغییری ایجاد نشد ';
            END IF;
    END;
END $$;

-- ==================== حالت 3: تراکنش ناموفق - نرخ بهره نامعتبر ====================
-- DO $$
-- BEGIN
--     BEGIN
--         CALL pr_register_loan(
--             3,
--             '3003000300030001',
--             10000000,
--             'BUSINESS',
--             75.5,  -- نرخ بهره بیش از حد
--             48
--         );

--         RAISE NOTICE 'خطا';

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
--             RAISE NOTICE ' Rollback شد ';
--     END;
-- END $$;
--حساب نامعتبر
DO $$
BEGIN
    BEGIN
        CALL pr_register_loan(
            3,
            '3003000300030881',
            10000000,
            'BUSINESS',
            10,
            48
        );

        RAISE NOTICE 'خطا';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';
    END;
END $$;
-- ================================================
-- tr_pay_bill
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
    RAISE NOTICE 'موفق';
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

        RAISE NOTICE 'موفق';

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
            RAISE NOTICE ' Rollback شد ';
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
    RAISE NOTICE 'ناموفق موحودی ناکافی';
    RAISE NOTICE 'موجودی فعلی: %', v_balance_before;

    BEGIN
        CALL pr_pay_bill(
            '1111001100110001',
            'WATER',
            99999999,  
            'WATER-TEST',
            'تست موجودی ناکافی'
        );

        RAISE NOTICE 'خطا';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';

            SELECT balance INTO v_balance_after 
            FROM account WHERE account_number = '1111001100110001';

            IF v_balance_before = v_balance_after THEN
                RAISE NOTICE 'موجودی بدون تغییر  ';
            END IF;
    END;
END $$;

-- ==================== حالت 3: تراکنش ناموفق - نوع پرداخت نامعتبر ====================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'ناموفق نوع پرداخت';

    BEGIN
        CALL pr_pay_bill(
            '2002000200020001',
            'INVALID_TYPE',  
            500000,
            'TEST-BILL',
            'تست نوع نامعتبر'
        );

        RAISE NOTICE 'خطا';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'خطای مورد انتظار: %', SQLERRM;
            RAISE NOTICE ' Rollback شد ';
    END;
END $$;