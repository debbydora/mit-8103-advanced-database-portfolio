-- Portfolio 2: Final index decisions (based on optimisation-tests.sql results)

-- KEEP - Test A: 960.683 ms -> 0.082 ms
CREATE INDEX IF NOT EXISTS idx_transfers_successful_completed_at
ON quickpay.transfers (completed_at DESC)
WHERE status = 'successful'
  AND completed_at IS NOT NULL;

-- KEEP - Test B: 124.437 ms -> 0.103 ms
CREATE INDEX IF NOT EXISTS idx_transfers_source_created
ON quickpay.transfers (source_account_id, created_at DESC);

-- DROP - Test C: never chosen by the planner (0 scans); storage/write cost only
DROP INDEX IF EXISTS quickpay.idx_transfers_created_at;
