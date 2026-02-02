-- TOY (Thinking Of You) Videos Storage Bucket
-- This migration creates the videos bucket and RLS policies for final montage storage
-- Run this in your Supabase SQL Editor to set up storage access control

-- ============================================================================
-- CREATE VIDEOS BUCKET
-- ============================================================================

-- Create the videos bucket as private (no public access)
-- Final montage videos are accessed via signed URLs only
INSERT INTO storage.buckets (id, name, public)
VALUES ('videos', 'videos', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES FOR storage.objects
-- ============================================================================

-- Allow authenticated users to upload videos (final montages)
-- This enables the StorageService.uploadMontage() method
CREATE POLICY "authenticated_insert_videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'videos');

-- Allow authenticated users to read (required for signed URL generation)
-- This enables the StorageService.createSignedVideoURL() method
CREATE POLICY "authenticated_select_videos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'videos');

-- Allow authenticated users to update (for upsert/re-publish if needed)
CREATE POLICY "authenticated_update_videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'videos');

-- Allow authenticated users to delete (for cleanup operations)
CREATE POLICY "authenticated_delete_videos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'videos');
