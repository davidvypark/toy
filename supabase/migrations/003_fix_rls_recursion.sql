-- Fix RLS policy recursion between cards and participants tables
-- The original policies had circular references causing "infinite recursion" errors
-- Solution: Use SECURITY DEFINER helper functions to bypass RLS during policy evaluation

-- ============================================================================
-- HELPER FUNCTIONS (SECURITY DEFINER bypasses RLS)
-- ============================================================================

-- Check if current user is a participant of a card (without triggering RLS)
CREATE OR REPLACE FUNCTION is_participant_of_card(card_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM participants
        WHERE card_id = card_uuid
        AND user_id = auth.uid()
    );
$$;

-- Check if current user is the host of a card (without triggering RLS)
CREATE OR REPLACE FUNCTION is_host_of_card(card_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM cards
        WHERE id = card_uuid
        AND host_id = auth.uid()
    );
$$;

-- ============================================================================
-- FIX CARDS POLICIES
-- ============================================================================

-- Drop the problematic policy
DROP POLICY IF EXISTS "Participants can read invited cards" ON cards;

-- Recreate using helper function (no recursion)
CREATE POLICY "Participants can read invited cards"
    ON cards
    FOR SELECT
    USING (is_participant_of_card(id));

-- ============================================================================
-- FIX PARTICIPANTS POLICIES
-- ============================================================================

-- Drop the problematic policies
DROP POLICY IF EXISTS "Hosts can read participants on own cards" ON participants;
DROP POLICY IF EXISTS "Hosts can insert participants on own cards" ON participants;
DROP POLICY IF EXISTS "Hosts can update participants on own cards" ON participants;
DROP POLICY IF EXISTS "Hosts can delete participants on own cards" ON participants;

-- Recreate using helper function (no recursion)
CREATE POLICY "Hosts can read participants on own cards"
    ON participants
    FOR SELECT
    USING (is_host_of_card(card_id));

CREATE POLICY "Hosts can insert participants on own cards"
    ON participants
    FOR INSERT
    WITH CHECK (is_host_of_card(card_id));

CREATE POLICY "Hosts can update participants on own cards"
    ON participants
    FOR UPDATE
    USING (is_host_of_card(card_id))
    WITH CHECK (is_host_of_card(card_id));

CREATE POLICY "Hosts can delete participants on own cards"
    ON participants
    FOR DELETE
    USING (is_host_of_card(card_id));

-- ============================================================================
-- FIX CLIPS POLICIES (same pattern)
-- ============================================================================

-- Drop the problematic policy
DROP POLICY IF EXISTS "Hosts can read clips on own cards" ON clips;
DROP POLICY IF EXISTS "Hosts can delete clips on own cards" ON clips;

-- Recreate using helper function
CREATE POLICY "Hosts can read clips on own cards"
    ON clips
    FOR SELECT
    USING (is_host_of_card(card_id));

CREATE POLICY "Hosts can delete clips on own cards"
    ON clips
    FOR DELETE
    USING (is_host_of_card(card_id));
