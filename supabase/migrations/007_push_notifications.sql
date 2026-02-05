-- Migration: Push Notifications Support
-- Adds device_tokens table and notification triggers

-- Device tokens table for APNs
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Index for efficient lookups by user
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own tokens
CREATE POLICY "Users can insert own tokens" ON device_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own tokens" ON device_tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens" ON device_tokens
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens" ON device_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- Updated at trigger
CREATE TRIGGER set_device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Note: The actual push notification sending is handled by a Supabase Edge Function
-- that is called via database webhook or directly from the app.
--
-- To set up notifications:
-- 1. Deploy the send-notification edge function
-- 2. Create a database webhook on clips INSERT to call the function
-- 3. Create a database webhook on cards UPDATE (status -> published) to call the function
--
-- Alternatively, call the edge function directly from the iOS app after
-- uploading a clip or publishing a card.
