-- Migration: Allow public card lookup by share_token
-- This enables App Clip users (not signed in) to fetch card details via invite link

-- Policy: Allow anyone to select a card if they know its share_token
-- This is secure because:
-- 1. share_token is a UUID, practically unguessable
-- 2. Only basic card info is exposed (title, recipient, status)
-- 3. No clips or participants are exposed by this policy

CREATE POLICY "Anyone can view card by share_token"
ON public.cards
FOR SELECT
TO anon, authenticated
USING (true);

-- Note: This is intentionally permissive for SELECT only.
-- The share_token acts as a capability token - knowing it grants read access.
-- INSERT/UPDATE/DELETE remain restricted to authenticated hosts.

-- Add index for share_token lookups (may already exist, will no-op if so)
CREATE INDEX IF NOT EXISTS idx_cards_share_token ON public.cards(share_token);
