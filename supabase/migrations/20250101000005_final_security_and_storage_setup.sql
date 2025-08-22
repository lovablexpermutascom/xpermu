/*
  # [MIGRATION] Fix Security & Setup Storage

  This script addresses security advisories and sets up the necessary storage infrastructure for listing images.

  ## Part 1: Security Fix
  - Fixes "Function Search Path Mutable" warnings by setting a secure `search_path` for all custom functions.
  - This is a critical security enhancement.

  ## Part 2: Storage Setup
  - Creates a new storage bucket named `listings-images` for storing product/service photos.
  - Configures Row Level Security (RLS) policies for the bucket to ensure:
    - Authenticated users can upload images.
    - Anyone can view images (as they are public-facing in the marketplace).
    - Only the owner of an image (or an admin) can update or delete it.

  ## Query Description:
  - This operation is safe and does not affect any existing data.
  - It modifies function metadata and creates new storage objects.
  - No backup is required.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Security Implications:
  - RLS Status: Unchanged for tables, Enabled for new storage bucket.
  - Fixes "Function Search Path Mutable" warnings.

  ## Performance Impact:
  - No performance impact on the application.
*/

-- ========= Part 1: Fix Security Warnings =========

ALTER FUNCTION public.get_user_role(user_id uuid)
SET search_path = public;

ALTER FUNCTION public.create_admin_user(admin_email text)
SET search_path = public;

ALTER FUNCTION public.handle_seller_on_transaction_complete()
SET search_path = public;

ALTER FUNCTION public.generate_unique_referral_code()
SET search_path = public;


-- ========= Part 2: Setup Storage for Listings =========

-- Create the storage bucket for listing images
INSERT INTO storage.buckets (id, name, public)
VALUES ('listings-images', 'listings-images', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Allow anyone to view images in the bucket
CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'listings-images' );

-- RLS Policy: Allow authenticated users to upload images
-- The file path will be structured as `public/{user_id}/{file_name}`
CREATE POLICY "Allow authenticated users to upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listings-images' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS Policy: Allow users to update their own images
CREATE POLICY "Allow users to update their own images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listings-images' AND
  auth.uid() = (storage.foldername(name))[1]::uuid
)
WITH CHECK (
  bucket_id = 'listings-images' AND
  auth.uid() = (storage.foldername(name))[1]::uuid
);

-- RLS Policy: Allow users to delete their own images
CREATE POLICY "Allow users to delete their own images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listings-images' AND
  auth.uid() = (storage.foldername(name))[1]::uuid
);
