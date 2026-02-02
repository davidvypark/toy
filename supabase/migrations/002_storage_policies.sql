-- TOY (Thinking Of You) Storage Policies
-- This migration creates the clips bucket and RLS policies for video storage
-- Run this in your Supabase SQL Editor to set up storage access control

-- ============================================================================
-- CREATE CLIPS BUCKET
-- ============================================================================

-- Create the clips bucket as private (no public access)
-- Videos are accessed via signed URLs only
INSERT INTO storage.buckets (id, name, public)
VALUES ('clips', 'clips', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES FOR storage.objects
-- ============================================================================

-- Allow authenticated users to upload clips
-- This enables the StorageService.uploadVideo() method
CREATE POLICY "authenticated_insert_clips"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'clips');

-- Allow authenticated users to read (required for signed URL generation)
-- This enables the StorageService.createSignedURL() method
CREATE POLICY "authenticated_select_clips"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'clips');

-- Allow authenticated users to update (for upsert/overwrite if needed later)
CREATE POLICY "authenticated_update_clips"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'clips');

-- Allow authenticated users to delete (for cleanup operations)
CREATE POLICY "authenticated_delete_clips"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'clips');
