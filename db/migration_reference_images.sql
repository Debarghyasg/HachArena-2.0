-- ============================================================================
-- Grahak Sathi — Per-SKU Reference Profile Images
-- ============================================================================
-- A "reference profile image" is the canonical photo of a product, captured
-- ONCE per SKU at first stock intake (receiving) and reused for every unit of
-- that SKU thereafter. It is the ground-truth the vision layer can later match
-- a scanned/refunded item against.
--
-- SKU MODEL: this system has no dedicated `sku` column — the per-product-type
-- identifier IS the barcode (EAN-13 / UPC-A), while `mk_id` is the per-UNIT
-- manufacturer serial. So one reference image per barcode == one per SKU, shared
-- by all mk_ids of that barcode.
--
-- STORAGE: unlike the per-transaction checkout/delivery images (base64 in DB),
-- reference images are long-lived, low-cardinality assets, so they live on the
-- filesystem under a fixed convention and only the PATH + link STATUS are stored
-- on the inventory row:
--
--     store-data/reference-images/{shop_id}/{barcode}.jpg
--
--   reference_image_path        relative path to the file above (NULL until linked)
--   reference_image_status      'pending' (no image yet) | 'linked' (image on file)
--   reference_image_updated_at  when the image was last (re)captured
--
-- Idempotent — safe to run multiple times.
-- ============================================================================

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS reference_image_path       TEXT,
    ADD COLUMN IF NOT EXISTS reference_image_status     TEXT NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS reference_image_updated_at TIMESTAMPTZ;

-- Fast lookup of SKUs still awaiting a reference image (manager upload queue).
CREATE INDEX IF NOT EXISTS idx_products_ref_img_status
    ON products (shop_id, reference_image_status);
