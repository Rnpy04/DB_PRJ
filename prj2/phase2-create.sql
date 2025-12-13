-- ================================================
-- Phase 2: Create Tables for Online Banking System
-- Database Management System: PostgreSQL
-- ================================================

-- Drop existing tables (if any) in reverse order of dependencies
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS loan CASCADE;
DROP TABLE IF EXISTS card CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS account CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS branch CASCADE;

-- ================================================
-- Table 1: Branch (شعبه)
-- ================================================
CREATE TABLE branch (
    branch_code VARCHAR(10) PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    phone VARCHAR(15) NOT NULL,
    working_hours VARCHAR(50),
    manager_name VARCHAR(100),
    CONSTRAINT chk_phone_format CHECK (phone ~ '^\d{10,15}$')
);

COMMENT ON TABLE branch IS 'اطلاعات شعب بانک';
COMMENT ON COLUMN branch.branch_code IS 'کد یکتای شعبه';
COMMENT ON COLUMN branch.working_hours IS 'ساعات کاری شعبه - مثال: 8:00-16:00';

-- ================================================
-- Table 2: Customer (مشتری)
-- ================================================
CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    national_id VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address TEXT,
    email VARCHAR(100),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_national_id CHECK (LENGTH(national_id) = 10),
    CONSTRAINT chk_birth_date CHECK (birth_date < CURRENT_DATE),
    CONSTRAINT chk_age CHECK (EXTRACT(YEAR FROM AGE(birth_date)) >= 18),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

COMMENT ON TABLE customer IS 'اطلاعات مشتریان بانک';
COMMENT ON COLUMN customer.national_id IS 'شماره ملی 10 رقمی - یکتا';
COMMENT ON COLUMN customer.registration_date IS 'تاریخ ثبت‌نام مشتری';

-- ================================================
-- Table 3: Employee (کارمند)
-- ================================================
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    national_id VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    salary DECIMAL(12, 2),
    branch_code VARCHAR(10) NOT NULL,
    CONSTRAINT fk_employee_branch FOREIGN KEY (branch_code) 
        REFERENCES branch(branch_code) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_emp_national_id CHECK (LENGTH(national_id) = 10),
    CONSTRAINT chk_hire_date CHECK (hire_date <= CURRENT_DATE),
    CONSTRAINT chk_salary CHECK (salary > 0)
);

COMMENT ON TABLE employee IS 'اطلاعات کارمندان بانک';
COMMENT ON COLUMN employee.position IS 'سمت کارمند - مثال: کارشناس، مدیر';

-- ================================================
-- Table 4: Account (حساب)
-- ================================================
CREATE TABLE account (
    account_number VARCHAR(16) PRIMARY KEY,
    account_type VARCHAR(20) NOT NULL,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0,
    opening_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    customer_id INTEGER NOT NULL,
    branch_code VARCHAR(10) NOT NULL,
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id) 
        REFERENCES customer(customer_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_account_branch FOREIGN KEY (branch_code) 
        REFERENCES branch(branch_code) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_account_type CHECK (account_type IN ('SAVINGS', 'CHECKING', 'DEPOSIT', 'CURRENT')),
    CONSTRAINT chk_balance CHECK (balance >= 0),
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED', 'CLOSED'))
);

COMMENT ON TABLE account IS 'اطلاعات حساب‌های بانکی مشتریان';
COMMENT ON COLUMN account.account_type IS 'نوع حساب: پس‌انداز، جاری، سپرده';
COMMENT ON COLUMN account.status IS 'وضعیت حساب: فعال، غیرفعال، مسدود، بسته';

-- ================================================
-- Table 5: Transaction (تراکنش)
-- ================================================
CREATE TABLE transaction (
    transaction_id SERIAL PRIMARY KEY,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    source_account VARCHAR(16) NOT NULL,
    destination_account VARCHAR(16),
    status VARCHAR(10) DEFAULT 'COMPLETED',
    CONSTRAINT fk_trans_source FOREIGN KEY (source_account) 
        REFERENCES account(account_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_trans_destination FOREIGN KEY (destination_account) 
        REFERENCES account(account_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_trans_type CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT')),
    CONSTRAINT chk_amount CHECK (amount > 0),
    CONSTRAINT chk_trans_status CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED'))
);

COMMENT ON TABLE transaction IS 'تمام تراکنش‌های مالی';
COMMENT ON COLUMN transaction.transaction_type IS 'نوع: واریز، برداشت، انتقال، پرداخت';
COMMENT ON COLUMN transaction.destination_account IS 'برای انتقال وجه - می‌تواند NULL باشد';

-- ================================================
-- Table 6: Card (کارت)
-- ================================================
CREATE TABLE card (
    card_number VARCHAR(16) PRIMARY KEY,
    expiry_date DATE NOT NULL,
    cvv VARCHAR(4) NOT NULL,
    card_type VARCHAR(15) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    account_number VARCHAR(16) NOT NULL,
    CONSTRAINT fk_card_account FOREIGN KEY (account_number) 
        REFERENCES account(account_number) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_card_type CHECK (card_type IN ('DEBIT', 'CREDIT', 'PREPAID')),
    CONSTRAINT chk_card_status CHECK (status IN ('ACTIVE', 'BLOCKED', 'EXPIRED', 'LOST')),
    CONSTRAINT chk_expiry CHECK (expiry_date > issue_date),
    CONSTRAINT chk_cvv CHECK (LENGTH(cvv) >= 3 AND LENGTH(cvv) <= 4)
);

COMMENT ON TABLE card IS 'کارت‌های بانکی متصل به حساب‌ها';
COMMENT ON COLUMN card.card_type IS 'نوع کارت: نقدی، اعتباری، پیش‌پرداخت';

-- ================================================
-- Table 7: Loan (وام)
-- ================================================
CREATE TABLE loan (
    loan_id SERIAL PRIMARY KEY,
    loan_amount DECIMAL(15, 2) NOT NULL,
    loan_type VARCHAR(30) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE NOT NULL,
    status VARCHAR(15) NOT NULL DEFAULT 'ACTIVE',
    remaining_amount DECIMAL(15, 2) NOT NULL,
    customer_id INTEGER NOT NULL,
    account_number VARCHAR(16) NOT NULL,
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id) 
        REFERENCES customer(customer_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_loan_account FOREIGN KEY (account_number) 
        REFERENCES account(account_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_loan_type CHECK (loan_type IN ('PERSONAL', 'HOME', 'CAR', 'EDUCATION', 'BUSINESS')),
    CONSTRAINT chk_loan_amount CHECK (loan_amount > 0),
    CONSTRAINT chk_interest_rate CHECK (interest_rate >= 0 AND interest_rate <= 50),
    CONSTRAINT chk_loan_dates CHECK (end_date > start_date),
    CONSTRAINT chk_remaining CHECK (remaining_amount >= 0 AND remaining_amount <= loan_amount),
    CONSTRAINT chk_loan_status CHECK (status IN ('ACTIVE', 'COMPLETED', 'DEFAULTED', 'CANCELLED'))
);

COMMENT ON TABLE loan IS 'وام‌های دریافتی مشتریان';
COMMENT ON COLUMN loan.loan_type IS 'نوع وام: شخصی، مسکن، خودرو، تحصیلی، تجاری';
COMMENT ON COLUMN loan.remaining_amount IS 'مبلغ باقیمانده وام';

-- ================================================
-- Table 8: Payment (پرداخت)
-- ================================================
CREATE TABLE payment (
    payment_id SERIAL PRIMARY KEY,
    payment_type VARCHAR(30) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    bill_number VARCHAR(20),
    status VARCHAR(15) NOT NULL DEFAULT 'COMPLETED',
    description TEXT,
    account_number VARCHAR(16) NOT NULL,
    CONSTRAINT fk_payment_account FOREIGN KEY (account_number) 
        REFERENCES account(account_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_payment_type CHECK (payment_type IN ('ELECTRICITY', 'WATER', 'GAS', 'PHONE', 'INTERNET', 'INSURANCE', 'TAX', 'OTHER')),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'))
);

COMMENT ON TABLE payment IS 'پرداخت قبوض و خدمات';
COMMENT ON COLUMN payment.payment_type IS 'نوع قبض: برق، آب، گاز، تلفن، بیمه';
COMMENT ON COLUMN payment.bill_number IS 'شماره قبض یا شناسه پرداخت';

-- ================================================
-- Create Indexes for Performance (Phase 4 Preview)
-- ================================================
-- These will be detailed in Phase 4, but primary/foreign keys 
-- automatically create indexes in PostgreSQL

-- ================================================
-- Display Success Message
-- ================================================
DO $$
BEGIN
    RAISE NOTICE 'تمام جداول با موفقیت ساخته شدند!';
    RAISE NOTICE 'تعداد جداول: 8';
    RAISE NOTICE 'پایگاه داده آماده برای Phase 3 (Insert Data) است';
END $$;