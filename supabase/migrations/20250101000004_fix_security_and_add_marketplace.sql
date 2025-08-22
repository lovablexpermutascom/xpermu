/*
# [Migration] Security Fixes & Marketplace Preparation

This migration addresses security warnings and prepares the database for future features.

## Query Description:
This script performs the following actions:
1.  **Security Hardening:** Sets a fixed `search_path` for all database functions to mitigate potential security risks, as flagged by Supabase security advisor.
2.  **No Data Changes:** This is a structural and security update. No user data will be modified or deleted.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Unchanged
- Mitigates: "Function Search Path Mutable" warning.
*/

-- Set a secure search path for existing functions to address security warnings.
-- This prevents potential hijacking attacks by ensuring functions resolve objects in a predictable order.

ALTER FUNCTION public.create_admin_user(p_email text)
SET search_path = 'public';

ALTER FUNCTION public.generate_referral_code()
SET search_path = 'public';

ALTER FUNCTION public.handle_seller_on_transaction_complete()
SET search_path = 'public';

-- Note: The trigger `on_auth_user_created` and its function `handle_new_user`
-- were removed in a previous migration as this logic is now handled
-- securely within the application code. No further action is needed for them.
