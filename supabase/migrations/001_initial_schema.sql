-- TOY (Thinking Of You) Initial Database Schema
-- This migration creates the core tables for the group video greeting card app
-- Run this in your Supabase SQL Editor to set up the database

-- ============================================================================
-- ENABLE EXTENSIONS
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLES
-- ============================================================================

-- profiles table (extends Supabase auth.users)
-- Stores additional user information beyond what auth.users provides
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- cards table
-- The main entity - a group video greeting card created by a host
CREATE TABLE cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL, -- e.g., "Happy Birthday Sarah!"
    recipient_name TEXT NOT NULL,
    occasion TEXT CHECK (occasion IN ('birthday', 'wedding', 'get_well', 'congratulations', 'holiday', 'other')),
    status TEXT DEFAULT 'draft' NOT NULL CHECK (status IN ('draft', 'collecting', 'stitching', 'published')),
    published_at TIMESTAMPTZ,
    video_url TEXT, -- Final stitched video URL
    share_token TEXT UNIQUE, -- For recipient viewing
    max_participants INTEGER DEFAULT 8,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- clips table
-- Individual video recordings from participants
CREATE TABLE clips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL, -- Supabase storage URL
    duration_seconds DECIMAL(4,2) CHECK (duration_seconds <= 7.0),
    order_position INTEGER, -- For montage ordering, host clip = 0
    status TEXT DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'uploaded', 'approved', 'rejected')),
    uploaded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- participants table (invitations)
-- Tracks who has been invited to contribute to a card
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- null until they record
    invite_token TEXT UNIQUE NOT NULL, -- For deep link
    email TEXT, -- Optional - if host invites by email
    status TEXT DEFAULT 'invited' NOT NULL CHECK (status IN ('invited', 'viewed', 'recording', 'submitted')),
    invited_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    submitted_at TIMESTAMPTZ
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Cards indexes
CREATE INDEX idx_cards_host_id ON cards(host_id);
CREATE INDEX idx_cards_share_token ON cards(share_token);

-- Clips indexes
CREATE INDEX idx_clips_card_id ON clips(card_id);
CREATE INDEX idx_clips_participant_id ON clips(participant_id);

-- Participants indexes
CREATE INDEX idx_participants_card_id ON participants(card_id);
CREATE INDEX idx_participants_invite_token ON participants(invite_token);
CREATE INDEX idx_participants_user_id ON participants(user_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles table
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for cards table
CREATE TRIGGER set_cards_updated_at
    BEFORE UPDATE ON cards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------
-- profiles policies
-- ----------------------------------------

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
    ON profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can insert own profile"
    ON profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- ----------------------------------------
-- cards policies
-- ----------------------------------------

-- Hosts can read their own cards
CREATE POLICY "Hosts can read own cards"
    ON cards
    FOR SELECT
    USING (auth.uid() = host_id);

-- Participants can read cards they're invited to
CREATE POLICY "Participants can read invited cards"
    ON cards
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE participants.card_id = cards.id
            AND participants.user_id = auth.uid()
        )
    );

-- Anyone with share_token can read published cards (for recipients)
CREATE POLICY "Recipients can read shared cards"
    ON cards
    FOR SELECT
    USING (
        status = 'published'
        AND share_token IS NOT NULL
    );

-- Hosts can insert their own cards
CREATE POLICY "Hosts can insert own cards"
    ON cards
    FOR INSERT
    WITH CHECK (auth.uid() = host_id);

-- Hosts can update their own cards
CREATE POLICY "Hosts can update own cards"
    ON cards
    FOR UPDATE
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

-- Hosts can delete their own cards
CREATE POLICY "Hosts can delete own cards"
    ON cards
    FOR DELETE
    USING (auth.uid() = host_id);

-- ----------------------------------------
-- clips policies
-- ----------------------------------------

-- Participants can read their own clips
CREATE POLICY "Participants can read own clips"
    ON clips
    FOR SELECT
    USING (auth.uid() = participant_id);

-- Hosts can read all clips on their cards
CREATE POLICY "Hosts can read clips on own cards"
    ON clips
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = clips.card_id
            AND cards.host_id = auth.uid()
        )
    );

-- Participants can insert their own clips
CREATE POLICY "Participants can insert own clips"
    ON clips
    FOR INSERT
    WITH CHECK (auth.uid() = participant_id);

-- Participants can update their own clips
CREATE POLICY "Participants can update own clips"
    ON clips
    FOR UPDATE
    USING (auth.uid() = participant_id)
    WITH CHECK (auth.uid() = participant_id);

-- Participants can delete their own clips
CREATE POLICY "Participants can delete own clips"
    ON clips
    FOR DELETE
    USING (auth.uid() = participant_id);

-- Hosts can delete clips on their cards
CREATE POLICY "Hosts can delete clips on own cards"
    ON clips
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = clips.card_id
            AND cards.host_id = auth.uid()
        )
    );

-- ----------------------------------------
-- participants policies
-- ----------------------------------------

-- Hosts can read participants on their cards
CREATE POLICY "Hosts can read participants on own cards"
    ON participants
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = participants.card_id
            AND cards.host_id = auth.uid()
        )
    );

-- Users can read their own participant records
CREATE POLICY "Users can read own participant records"
    ON participants
    FOR SELECT
    USING (auth.uid() = user_id);

-- Hosts can insert participants on their cards
CREATE POLICY "Hosts can insert participants on own cards"
    ON participants
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = card_id
            AND cards.host_id = auth.uid()
        )
    );

-- Hosts can update participants on their cards
CREATE POLICY "Hosts can update participants on own cards"
    ON participants
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = participants.card_id
            AND cards.host_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = participants.card_id
            AND cards.host_id = auth.uid()
        )
    );

-- Participants can update their own status (when recording/submitting)
CREATE POLICY "Participants can update own status"
    ON participants
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Hosts can delete participants on their cards
CREATE POLICY "Hosts can delete participants on own cards"
    ON participants
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM cards
            WHERE cards.id = participants.card_id
            AND cards.host_id = auth.uid()
        )
    );

-- ============================================================================
-- HELPER FUNCTION: Create profile on signup
-- ============================================================================

-- This function is called via a Supabase trigger when a new user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
