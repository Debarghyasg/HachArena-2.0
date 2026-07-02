-- ============================================================================
-- Grahak Sathi — Capture ↔ Reference match score on the transaction record
-- ============================================================================
-- After an approved scan's checkout image is captured, it is compared with YOLO
-- against the scanned SKU's stored reference profile image, producing a 0–1
-- confidence. That score is written back onto the transaction row so it forms
-- part of the audit trail and can drive the manager-review path (e.g. surface
-- scans whose capture_match_score fell below the review threshold).
--
--   capture_match_score  0.000–1.000 confidence the captured item matches the
--                        SKU reference image (NULL = not scored / inconclusive)
--   capture_ref          the capture reference (CAP-…) linking to the stored
--                        image + Redis txn:capture:{ref} state
--   capture_match_at     when the match was computed
--
-- Idempotent — safe to run multiple times.
-- ============================================================================

ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS capture_match_score NUMERIC(4,3),
    ADD COLUMN IF NOT EXISTS capture_ref         TEXT,
    ADD COLUMN IF NOT EXISTS capture_match_at    TIMESTAMPTZ;

-- Manager-review queue: quickly find low-confidence captures needing a look.
CREATE INDEX IF NOT EXISTS idx_transactions_capture_score
    ON transactions (shop_id, capture_match_score);
CREATE INDEX IF NOT EXISTS idx_transactions_capture_ref
    ON transactions (capture_ref);
