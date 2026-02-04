-- Migration: Add thumbnail_url to clips table
-- This allows storing pre-generated thumbnails for fast loading

ALTER TABLE clips ADD COLUMN thumbnail_url TEXT;

-- Add comment for documentation
COMMENT ON COLUMN clips.thumbnail_url IS 'Storage path to pre-generated thumbnail image (JPEG)';
