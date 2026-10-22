-- Portfolio 2: Candidate optimisation for Query 2
-- Supports filtering and ordering recent successful transfers.
CREATE INDEX idx_transfers_successful_completed_at
ON quickpay.transfers (completed_at DESC)
WHERE status = 'successful'
  AND completed_at IS NOT NULL;