-- ============================================================================
-- Migration 017: Add model_media column to orders table
-- Allows attaching photos and videos of custom customer models upon order creation.
-- ============================================================================

ALTER TABLE orders ADD COLUMN IF NOT EXISTS model_media jsonb NOT NULL DEFAULT '[]'::jsonb;
