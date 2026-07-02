-- ============================================================================
-- Grahak Sathi — Capture-match decision + per-store sensitivity thresholds
-- ============================================================================
-- The 0–1 capture↔reference confidence (migration_capture_match.sql) is turned
-- into an action by threshold branching:
--
--     score >  approve_threshold        → auto_approve   (finalize the sale)
--     block_threshold < score ≤ approve → manager_review (hold for a human)
--     score ≤  block_threshold          → auto_block     (fraud-alert flow)
--
-- The resolved decision is written onto the transaction row for the audit trail
-- and the manager-review queue. The thresholds themselves are stored PER STORE
-- (not hardcoded) so a shop can tune its own sensitivity later; they default to
-- 0.90 / 0.60 and fall back to the env defaults if unset.
--
-- Idempotent — safe to run multiple times.
-- ============================================================================

-- Resolved decision on the transaction record.
ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS capture_decision TEXT;   -- auto_approve | manager_review | auto_block

CREATE INDEX IF NOT EXISTS idx_transactions_capture_decision
    ON transactions (shop_id, capture_decision);

-- Per-store, tunable sensitivity thresholds.
ALTER TABLE retailers
    ADD COLUMN IF NOT EXISTS capture_approve_threshold NUMERIC(4,3) NOT NULL DEFAULT 0.900,
    ADD COLUMN IF NOT EXISTS capture_block_threshold   NUMERIC(4,3) NOT NULL DEFAULT 0.600;
