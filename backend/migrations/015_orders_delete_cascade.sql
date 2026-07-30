-- ============================================================================
-- Migration 015: Allow orders to be deleted without FK constraint violations.
-- Unlink tailor_daily_entries.order_id ON DELETE SET NULL or via safe transaction.
-- ============================================================================

DO $$
BEGIN
  -- Drop constraint if exists and recreate with ON DELETE SET NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'tailor_daily_entries_order_id_fkey'
  ) THEN
    ALTER TABLE tailor_daily_entries DROP CONSTRAINT tailor_daily_entries_order_id_fkey;
  END IF;

  ALTER TABLE tailor_daily_entries ADD CONSTRAINT tailor_daily_entries_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;
