-- =====================================================
-- Quickpay Fintech Database
-- Portfolio 1: Database Design and Implementation
-- PostgreSQL
-- =====================================================

-- 1. Create a dedicated schema for Quickpay
CREATE SCHEMA IF NOT EXISTS Quickpay;

-- 2. Set the schema for subsequent statements
SET search_path TO Quickpay, public;


-- =====================================================
-- TABLE 1: CUSTOMERS
-- Stores customer information
-- =====================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,

    email VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),

    date_of_birth DATE,

    status VARCHAR(20) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_customers_status
        CHECK (status IN ('active', 'suspended', 'closed')),

    CONSTRAINT chk_customers_email
        CHECK (email = TRIM(email) AND email <> ''),

    CONSTRAINT chk_customers_first_name
        CHECK (first_name = TRIM(first_name) AND first_name <> ''),

    CONSTRAINT chk_customers_last_name
        CHECK (last_name = TRIM(last_name) AND last_name <> '')
);

-- Prevent duplicate email addresses, ignoring letter case
CREATE UNIQUE INDEX IF NOT EXISTS uq_customers_email_lower
    ON customers (LOWER(email));


-- =====================================================
-- TABLE 2: ACCOUNTS
-- Stores customer bank accounts and their balances
-- =====================================================

CREATE TABLE IF NOT EXISTS accounts (
    account_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_id BIGINT NOT NULL,

    account_number VARCHAR(20) NOT NULL UNIQUE,

    account_type VARCHAR(20) NOT NULL DEFAULT 'savings',

    currency CHAR(3) NOT NULL DEFAULT 'NGN',

    balance NUMERIC(19, 4) NOT NULL DEFAULT 0.0000,

    status VARCHAR(20) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_accounts_type
        CHECK (account_type IN ('savings', 'current', 'wallet')),

    CONSTRAINT chk_accounts_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_accounts_balance
        CHECK (balance >= 0),

    CONSTRAINT chk_accounts_status
        CHECK (status IN ('active', 'frozen', 'closed')),

    CONSTRAINT chk_accounts_number
        CHECK (
            account_number = TRIM(account_number)
            AND account_number <> ''
        )
);

CREATE INDEX IF NOT EXISTS idx_accounts_customer_id
    ON accounts (customer_id);

CREATE INDEX IF NOT EXISTS idx_accounts_status
    ON accounts (status);


-- =====================================================
-- TABLE 3: TRANSFERS
-- Records money transfers between accounts
-- =====================================================

CREATE TABLE IF NOT EXISTS transfers (
    transfer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source_account_id BIGINT NOT NULL,
    destination_account_id BIGINT NOT NULL,

    amount NUMERIC(19, 4) NOT NULL,

    currency CHAR(3) NOT NULL DEFAULT 'NGN',

    status VARCHAR(20) NOT NULL DEFAULT 'pending',

    reference VARCHAR(100) NOT NULL UNIQUE,

    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,

    CONSTRAINT fk_transfers_source_account
        FOREIGN KEY (source_account_id)
        REFERENCES accounts (account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfers_destination_account
        FOREIGN KEY (destination_account_id)
        REFERENCES accounts (account_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transfers_amount
        CHECK (amount > 0),

    CONSTRAINT chk_transfers_different_accounts
        CHECK (source_account_id <> destination_account_id),

    CONSTRAINT chk_transfers_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_transfers_status
        CHECK (
            status IN (
                'pending',
                'processing',
                'successful',
                'failed',
                'reversed'
            )
        ),

    CONSTRAINT chk_transfers_completion
        CHECK (
            status <> 'successful'
            OR completed_at IS NOT NULL
        )
);

CREATE INDEX IF NOT EXISTS idx_transfers_source_account
    ON transfers (source_account_id);

CREATE INDEX IF NOT EXISTS idx_transfers_destination_account
    ON transfers (destination_account_id);

CREATE INDEX IF NOT EXISTS idx_transfers_status_created
    ON transfers (status, created_at DESC);


-- =====================================================
-- TABLE 4: LEDGER ENTRIES
-- Records the debit and credit sides of transfers
-- =====================================================

CREATE TABLE IF NOT EXISTS ledger_entries (
    ledger_entry_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    transfer_id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,

    entry_type VARCHAR(10) NOT NULL,

    amount NUMERIC(19, 4) NOT NULL,

    currency CHAR(3) NOT NULL DEFAULT 'NGN',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ledger_transfer
        FOREIGN KEY (transfer_id)
        REFERENCES transfers (transfer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ledger_account
        FOREIGN KEY (account_id)
        REFERENCES accounts (account_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_ledger_entry_type
        CHECK (entry_type IN ('debit', 'credit')),

    CONSTRAINT chk_ledger_amount
        CHECK (amount > 0),

    CONSTRAINT chk_ledger_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT uq_ledger_transfer_account_type
        UNIQUE (transfer_id, account_id, entry_type)
);

CREATE INDEX IF NOT EXISTS idx_ledger_account_created
    ON ledger_entries (account_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_transfer_id
    ON ledger_entries (transfer_id);


-- =====================================================
-- TABLE 5: AUDIT LOGS
-- Records important system activities
-- =====================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    audit_log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    actor_customer_id BIGINT,

    action VARCHAR(100) NOT NULL,

    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100),

    details JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_actor
        FOREIGN KEY (actor_customer_id)
        REFERENCES customers (customer_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_audit_action
        CHECK (TRIM(action) <> ''),

    CONSTRAINT chk_audit_entity_type
        CHECK (TRIM(entity_type) <> ''),

    CONSTRAINT chk_audit_details_object
        CHECK (JSONB_TYPEOF(details) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON audit_logs (actor_customer_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
    ON audit_logs (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
    ON audit_logs (created_at DESC);


-- =====================================================
-- END OF Quickpay SCHEMA
-- =====================================================