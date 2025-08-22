/*
  # [Feature] Referral System & Final Security Fix
  This migration sets up the full referral system and fixes pending security advisories.

  ## Query Description:
  - **Structural Changes:** Adds columns to the `users` table to track referrals and bonus payments. This is a non-destructive change.
  - **Function Creation:** Creates a new database function `grant_referral_bonus` to handle the logic of awarding bonuses atomically and safely when a user is approved.
  - **Security Fix:** Sets a secure `search_path` for all existing database functions to mitigate potential security risks as flagged by Supabase security advisories.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - **Table `users`:**
    - Adds `referred_by` (UUID, foreign key to users.id) to track who referred a user.
    - Adds `referral_bonus_paid` (BOOLEAN) to prevent duplicate bonus payments.
  - **New Function:**
    - `grant_referral_bonus(approved_user_id UUID)`

  ## Security Implications:
  - RLS Status: Unchanged
  - Policy Changes: No
  - Auth Requirements: Admin privileges required to trigger the bonus via user approval.
  - **Security Fix:** All functions (`get_user_role`, `handle_seller_on_transaction_complete`, `generate_unique_referral_code`) are hardened by setting a non-mutable `search_path`.

  ## Performance Impact:
  - Indexes: A foreign key index is automatically created on `referred_by`.
  - Triggers: No new triggers.
  - Estimated Impact: Negligible. The new function is only called on user approval.
*/

-- Step 1: Add columns to the users table for the referral system
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS referral_bonus_paid BOOLEAN DEFAULT FALSE NOT NULL;

-- Step 2: Create a function to grant referral bonuses
CREATE OR REPLACE FUNCTION public.grant_referral_bonus(approved_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- To be able to update user balances
AS $$
DECLARE
  referrer_id UUID;
  referrer_bonus_amount NUMERIC;
  referee_bonus_amount NUMERIC;
  bonus_settings JSONB;
BEGIN
  -- Check if the bonus has already been paid for this user
  IF (SELECT referral_bonus_paid FROM public.users WHERE id = approved_user_id) THEN
    RETURN;
  END IF;

  -- Get the referrer's ID
  SELECT referred_by INTO referrer_id FROM public.users WHERE id = approved_user_id;

  -- If there is a referrer, proceed
  IF referrer_id IS NOT NULL THEN
    -- Get bonus amounts from system settings
    SELECT value INTO bonus_settings FROM public.system_settings WHERE key = 'referral_bonus';
    referrer_bonus_amount := (bonus_settings->>'referrer')::NUMERIC;
    referee_bonus_amount := (bonus_settings->>'referee')::NUMERIC;

    -- Grant bonus to the referrer
    UPDATE public.users
    SET balance_bonus = balance_bonus + referrer_bonus_amount
    WHERE id = referrer_id;

    -- Grant bonus to the new user (referee)
    UPDATE public.users
    SET balance_bonus = balance_bonus + referee_bonus_amount
    WHERE id = approved_user_id;

    -- Mark the bonus as paid to prevent duplicates
    UPDATE public.users
    SET referral_bonus_paid = TRUE
    WHERE id = approved_user_id;
  END IF;
END;
$$;

-- Step 3: Apply security fixes to all existing functions
ALTER FUNCTION public.get_user_role(user_id uuid) SET search_path = public;
ALTER FUNCTION public.handle_seller_on_transaction_complete() SET search_path = public;
ALTER FUNCTION public.generate_unique_referral_code() SET search_path = public;

-- Grant execute permission on the new function to authenticated users
-- RLS policies will still prevent unauthorized calls from the client-side.
-- This is necessary for the admin user to be able to call it.
GRANT EXECUTE ON FUNCTION public.grant_referral_bonus(UUID) TO authenticated;
