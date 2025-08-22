/*
          # [Admin Panel & System Settings]
          This migration creates the necessary infrastructure for the admin panel, including a table for system-wide settings.

          ## Query Description:
          - Creates a `system_settings` table to store key-value configurations, like referral bonuses.
          - Inserts default values for these settings.
          - Enables Row Level Security (RLS) on the new table.
          - Creates policies to ensure only authenticated administrators can read and write to the settings table.
          This operation is safe and will not affect existing data.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - New Table: `system_settings`
          - Columns: `key`, `value`, `description`, `created_at`, `updated_at`
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes (new policies for `system_settings`)
          - Auth Requirements: Admin role required for access.
          
          ## Performance Impact:
          - Indexes: Primary key on `key` column.
          - Triggers: None
          - Estimated Impact: Negligible performance impact.
          */

-- 1. Create system_settings table
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Enable RLS
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies
DROP POLICY IF EXISTS "Allow admin read access" ON public.system_settings;
CREATE POLICY "Allow admin read access"
ON public.system_settings
FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

DROP POLICY IF EXISTS "Allow admin write access" ON public.system_settings;
CREATE POLICY "Allow admin write access"
ON public.system_settings
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

-- 4. Insert default settings (if they don't exist)
INSERT INTO public.system_settings (key, value, description)
VALUES
    ('referral_bonus', '{"referrer": 5.00, "referee": 2.50}', 'Bonus in € for referrer and new user on approved registration.'),
    ('transaction_commission_rate', '{"rate": 0.10}', 'Commission rate (10%) on each transaction.')
ON CONFLICT (key) DO NOTHING;

-- Create a trigger function to update the updated_at column
CREATE OR REPLACE FUNCTION public.handle_system_settings_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically update the updated_at column on any change
DROP TRIGGER IF EXISTS on_system_settings_update ON public.system_settings;
CREATE TRIGGER on_system_settings_update
BEFORE UPDATE ON public.system_settings
FOR EACH ROW
EXECUTE FUNCTION public.handle_system_settings_update();
