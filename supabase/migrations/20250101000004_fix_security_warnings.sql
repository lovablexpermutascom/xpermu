/*
# [Security Fix] Set Search Path for Functions
This migration addresses the "Function Search Path Mutable" security warnings by explicitly setting the search_path for all user-defined functions. This prevents potential schema-hijacking attacks.

## Query Description:
This operation modifies the metadata of existing functions. It is a safe, non-destructive operation that does not affect any data. It enhances the security of the database.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Not Affected
- Policy Changes: No
- Auth Requirements: None
- Fixes: "Function Search Path Mutable" warnings.
*/

ALTER FUNCTION public.create_admin_user(admin_email text) SET search_path = public;

ALTER FUNCTION public.handle_seller_on_transaction_complete() SET search_path = public;

ALTER FUNCTION public.generate_unique_referral_code() SET search_path = public;
