-- creating the dummy customer accounts data
INSERT INTO quickpay.customers (
    first_name,
    last_name,
    email,
    phone_number,
    date_of_birth,
    status
)
VALUES
    (
        'Ada',
        'Okafor',
        'ada.okafor@example.com',
        '08030000001',
        '1995-04-12',
        'active'
    ),
    (
        'Tunde',
        'Bakare',
        'tunde.bakare@example.com',
        '08030000002',
        '1992-08-25',
        'active'
    ),
    (
        'Ngozi',
        'Eze',
        'ngozi.eze@example.com',
        '08030000003',
        '1998-01-17',
        'active'
    ),
    (
        'Chinedu',
        'Okoro',
        'chinedu.okoro@example.com',
        '08030000004',
        '1990-11-03',
        'closed'
    ),
    (
        'Zainab',
        'Yusuf',
        'zainab.yusuf@example.com',
        '08030000005',
        '1996-06-21',
        'active'
    )
RETURNING *;

-- To seed the accounts table, the query has to be run to get the customer_id values from the customers table. The following query retrieves the customer_id values for the seeded customers:
SELECT
    customer_id,
    first_name,
    last_name,
    email,
    status,
    created_at
FROM quickpay.customers
ORDER BY customer_id;


-- This query seeds the accounts table with dummy data for each customer. The customer_id values are retrieved from the customers table to ensure that the accounts are associated with the correct customers.

INSERT INTO quickpay.accounts  (
    customer_id,
    account_number,
    account_type,
    currency,
    balance,
    status
)
VALUES
    (
       5,
        'SP1000000001',
        'savings',
        'NGN',
        150000.00,
        'active'
    ),
    (
        6,
        'SP1000000002',
        'current',
        'NGN',
        275000.00,
        'active'
    ),
    (
        7,
        'SP1000000003',
        'savings',
        'NGN',
        82500.00,
        'active'
    ),
    (
       8,
        'SP1000000004',
        'savings',
        'NGN',
        0.00,
        'closed'
    ),
    (
       9,
        'SP1000000005',
        'current',
        'NGN',
        430000.00,
        'active'
    )
RETURNING *;

--this data is for the transfers table, which records money transfers between accounts. The source_account_id and destination_account_id values are retrieved from the accounts table to ensure that the transfers are associated with the correct accounts.


INSERT INTO quickpay.transfers (
    source_account_id,
    destination_account_id,
    amount,
    currency,
    status,
    reference,
    description,
    created_at,
    completed_at
)
VALUES
    (
        1, 2, 25000.0000, 'NGN', 'successful',
        'SWP-TRF-2026-0001',
        'Transfer for household expenses',
        '2026-09-01 09:15:00+01',
        '2026-09-01 09:15:05+01'
    ),
    (
        2, 3, 15000.0000, 'NGN', 'successful',
        'SWP-TRF-2026-0002',
        'Payment for services',
        '2026-09-02 11:30:00+01',
        '2026-09-02 11:30:04+01'
    ),
    (
        3, 4, 5000.0000, 'NGN', 'pending',
        'SWP-TRF-2026-0003',
        'Pending personal transfer',
        '2026-09-03 14:20:00+01',
        NULL
    ),
    (
        4, 5, 12000.0000, 'NGN', 'processing',
        'SWP-TRF-2026-0004',
        'Vendor payment being processed',
        '2026-09-04 10:00:00+01',
        NULL
    ),
    (
        5, 1, 7500.0000, 'NGN', 'failed',
        'SWP-TRF-2026-0005',
        'Transfer unsuccessful due to a processing error',
        '2026-09-05 16:45:00+01',
        NULL
    ),
    (
        1, 3, 40000.0000, 'NGN', 'successful',
        'SWP-TRF-2026-0006',
        'School fees payment',
        '2026-09-06 08:10:00+01',
        '2026-09-06 08:10:06+01'
    ),
    (
        2, 5, 18000.0000, 'NGN', 'reversed',
        'SWP-TRF-2026-0007',
        'Transfer reversed after review',
        '2026-09-07 12:00:00+01',
        NULL
    ),
    (
        3, 1, 9500.0000, 'NGN', 'successful',
        'SWP-TRF-2026-0008',
        'Repayment between customers',
        '2026-09-08 13:25:00+01',
        '2026-09-08 13:25:03+01'
    ),
    (
        4, 2, 22000.0000, 'NGN', 'pending',
        'SWP-TRF-2026-0009',
        'Pending rent contribution',
        '2026-09-09 15:40:00+01',
        NULL
    ),
    (
        5, 3, 6500.0000, 'NGN', 'successful',
        'SWP-TRF-2026-0010',
        'Payment for groceries',
        '2026-09-10 17:05:00+01',
        '2026-09-10 17:05:04+01'
    )
RETURNING *;


--seeding the legdger table with dummy data for each transfer. The transfer_id values are retrieved from the transfers table to ensure that the ledger entries are associated with the correct transfers.--

INSERT INTO quickpay.ledger_entries (
    transfer_id,
    account_id,
    entry_type,
    amount,
    currency
)
VALUES
    -- Transfer 1: Account 1 sends ₦25,000 to account 2
    (1, 1, 'debit',  25000.0000, 'NGN'),
    (1, 2, 'credit', 25000.0000, 'NGN'),

    -- Transfer 2: Account 2 sends ₦15,000 to account 3
    (2, 2, 'debit',  15000.0000, 'NGN'),
    (2, 3, 'credit', 15000.0000, 'NGN'),

    -- Transfer 6: Account 1 sends ₦40,000 to account 3
    (6, 1, 'debit',  40000.0000, 'NGN'),
    (6, 3, 'credit', 40000.0000, 'NGN'),

    -- Transfer 8: Account 3 sends ₦9,500 to account 1
    (8, 3, 'debit',   9500.0000, 'NGN'),
    (8, 1, 'credit',  9500.0000, 'NGN'),

    -- Transfer 10: Account 5 sends ₦6,500 to account 3
    (10, 5, 'debit',  6500.0000, 'NGN'),
    (10, 3, 'credit', 6500.0000, 'NGN')
RETURNING *;

--seeding the audit_logs table with dummy data for each transfer. The transfer_id values are retrieved from the transfers table to ensure that the audit logs are associated with the correct transfers.--

INSERT INTO quickpay.audit_logs (
    actor_customer_id,
    action,
    entity_type,
    entity_id,
    details,
    created_at
)
VALUES
    (
        5,
        'ACCOUNT_CREATED',
        'account',
        '1',
        '{"account_number": "SP1000000001", "account_type": "savings"}'::JSONB,
        '2026-09-01 08:00:00+01'
    ),
    (
        6,
        'ACCOUNT_CREATED',
        'account',
        '2',
        '{"account_number": "SP1000000002", "account_type": "current"}'::JSONB,
        '2026-09-01 08:30:00+01'
    ),
    (
        5,
        'TRANSFER_INITIATED',
        'transfer',
        '1',
        '{"amount": 25000.0000, "currency": "NGN", "source_account_id": 1, "destination_account_id": 2}'::JSONB,
        '2026-09-01 09:15:00+01'
    ),
    (
        6,
        'TRANSFER_RECEIVED',
        'transfer',
        '1',
        '{"amount": 25000.0000, "currency": "NGN", "status": "successful"}'::JSONB,
        '2026-09-01 09:15:05+01'
    ),
    (
        7,
        'TRANSFER_INITIATED',
        'transfer',
        '2',
        '{"amount": 15000.0000, "currency": "NGN", "source_account_id": 2, "destination_account_id": 3}'::JSONB,
        '2026-09-02 11:30:00+01'
    ),
    (
        8,
        'TRANSFER_INITIATED',
        'transfer',
        '3',
        '{"amount": 5000.0000, "currency": "NGN", "status": "pending"}'::JSONB,
        '2026-09-03 14:20:00+01'
    ),
    (
        9,
        'TRANSFER_FAILED',
        'transfer',
        '5',
        '{"amount": 7500.0000, "currency": "NGN", "reason": "processing_error"}'::JSONB,
        '2026-09-05 16:45:00+01'
    ),
    (
        5,
        'ACCOUNT_DETAILS_VIEWED',
        'account',
        '1',
        '{"channel": "web", "result": "success"}'::JSONB,
        '2026-09-06 10:00:00+01'
    ),
    (
        7,
        'TRANSFER_REVERSED',
        'transfer',
        '7',
        '{"amount": 18000.0000, "currency": "NGN", "reason": "review"}'::JSONB,
        '2026-09-07 12:00:00+01'
    ),
    (
        NULL,
        'SYSTEM_RECONCILIATION',
        'ledger',
        NULL,
        '{"result": "completed", "source": "scheduled_job"}'::JSONB,
        '2026-09-10 23:00:00+01'
    )
RETURNING *;