-- DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS loan CASCADE;
DROP TABLE IF EXISTS card CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS account CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS branch CASCADE;
DROP TABLE IF EXISTS bank CASCADE;

CREATE TABLE bank (
    bank_id VARCHAR(10) PRIMARY KEY,
    bank_name VARCHAR(100) UNIQUE NOT NULL ,
    central_branch VARCHAR(10)
);

CREATE TABLE branch (
    branch_code VARCHAR(10) PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    bank_id VARCHAR(10) NOT NULL,
    address TEXT NOT NULL,
    phone VARCHAR(15) NOT NULL,
    working_hours VARCHAR(50) not null,

    CONSTRAINT chk_phone_format CHECK (phone ~ '^\d{10,15}$'),
    CONSTRAINT fk_bank FOREIGN KEY (bank_id) 
        REFERENCES bank(bank_id) 
        ON DELETE cascade,
        ON UPDATE cascade
);

ALTER TABLE bank
    ADD CONSTRAINT fk_branch FOREIGN KEY (central_branch) 
        REFERENCES branch(branch_code) 
        ON DELETE set null
        ON UPDATE CASCADE;


CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    national_id VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address TEXT not null,
    email VARCHAR(100),    

    CONSTRAINT chk_national_id CHECK (LENGTH(national_id) = 10),
    CONSTRAINT chk_age CHECK (birth_date <= CURRENT_DATE - INTERVAL '18 years'),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')

);

CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    national_id VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address TEXT not null,
    email VARCHAR(100),
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    salary DECIMAL(12, 2),
    branch_code VARCHAR(10) ,

    CONSTRAINT fk_employee_branch FOREIGN KEY (branch_code) 
        REFERENCES branch(branch_code) 
        ON DELETE set null 
        ON UPDATE CASCADE,
    CONSTRAINT chk_emp_national_id CHECK (LENGTH(national_id) = 10),
    CONSTRAINT chk_salary CHECK (salary > 0)
);

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

CREATE TABLE transactions (
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

    CHECK (
        (transaction_type = 'TRANSFER' AND destination_account IS NOT NULL)
    OR (transaction_type <> 'TRANSFER')
    ),
    CONSTRAINT chk_trans_type CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT')),
    CONSTRAINT chk_amount CHECK (amount > 0),
    CONSTRAINT chk_trans_status CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED'))
);

CREATE TABLE card (
    card_number VARCHAR(16) PRIMARY KEY,
    exp_date DATE NOT NULL,
    cvv2 VARCHAR(4) NOT NULL,
    card_type VARCHAR(15) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    account_number VARCHAR(16) NOT NULL,
    CONSTRAINT fk_card_account FOREIGN KEY (account_number) 
        REFERENCES account(account_number) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_card_type CHECK (card_type IN ('DEBIT', 'CREDIT', 'PREPAID')),
    CONSTRAINT chk_card_status CHECK (status IN ('ACTIVE', 'BLOCKED', 'EXPIRED', 'LOST')),
    CONSTRAINT chk_cvv2 CHECK (LENGTH(cvv2) >= 3 AND LENGTH(cvv2) <= 4),
    CONSTRAINT uq_account_card_type UNIQUE (account_number, card_type)

);

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
    CONSTRAINT chk_loan_dates CHECK (end_date > start_date),
    CONSTRAINT chk_remaining CHECK (remaining_amount >= 0 AND remaining_amount <= loan_amount),
    CONSTRAINT chk_loan_status CHECK (status IN ('ACTIVE', 'COMPLETED', 'DEFAULTED', 'CANCELLED'))
);

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