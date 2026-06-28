-- ============================================================================
-- SmartRetail — Customer purchase ledger (transaction_items)
-- ============================================================================
-- The canonical "customer database" of what each customer actually bought.
--
-- When a customer self-checks-out, the gateway issues a transaction_id (tied to
-- their session) and writes ONE ROW PER PURCHASED UNIT here — independent of
-- whether a product photo was captured. This is the record the support chatbot
-- later uses to verify a refund: the MK-ID/barcode read from the customer's
-- photo must match an item bought under that transaction, otherwise the refund
-- is rejected as a product mismatch.
--
-- (checkout_images still stores the captured photo per item; transaction_items
--  is the always-present item ledger that does not depend on an image.)
--
-- Safe to run multiple times (IF NOT EXISTS).
-- ============================================================================

CREATE TABLE IF NOT EXISTS transaction_items (
    id                    BIGSERIAL PRIMARY KEY,
    transaction_id        TEXT        NOT NULL,        -- receipt id issued at checkout
    session_id            TEXT,                         -- customer session the sale belongs to
    user_id               TEXT,                         -- customer identifier (session token / login)
    shop_id               INTEGER,                      -- retailer/shop id
    barcode               TEXT,                         -- product barcode (EAN-13 / UPC-A)
    mk_id                 TEXT,                         -- manufacturer serial of the unit (if scanned)
    product_name          TEXT,                         -- resolved product name at sale time
    quantity              INTEGER     NOT NULL DEFAULT 1,
    price                 NUMERIC,                      -- unit price at sale time
    purchase_channel      TEXT        NOT NULL DEFAULT 'offline',  -- offline (in-store) | online
    return_eligible_until TIMESTAMPTZ,                  -- created_at + RETURN_WINDOW_DAYS
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transaction_items_txn     ON transaction_items (transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_mkid    ON transaction_items (mk_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_barcode ON transaction_items (barcode);
CREATE INDEX IF NOT EXISTS idx_transaction_items_session ON transaction_items (session_id);
