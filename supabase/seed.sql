-- TOY (Thinking Of You) Seed Data
-- This file contains sample data for local development only
-- DO NOT run this in production

-- ============================================================================
-- IMPORTANT: Before running this seed file, you need:
-- 1. At least one user created via Supabase Auth (sign up in your app)
-- 2. Replace the UUIDs below with actual user IDs from your auth.users table
-- ============================================================================

-- To find user IDs, run this query in Supabase SQL Editor:
-- SELECT id, email FROM auth.users;

-- ============================================================================
-- SAMPLE DATA (COMMENTED OUT - REQUIRES VALID USER IDS)
-- ============================================================================

-- Uncomment and modify the following after you have users in your system:

/*
-- Sample card for development testing
-- Replace 'YOUR_USER_UUID_HERE' with an actual user ID

INSERT INTO cards (
    id,
    host_id,
    title,
    recipient_name,
    occasion,
    status,
    max_participants
) VALUES (
    gen_random_uuid(),
    'YOUR_USER_UUID_HERE'::uuid, -- Replace with actual host user ID
    'Happy Birthday Sarah!',
    'Sarah',
    'birthday',
    'collecting',
    8
);

-- To get the card_id for the sample participant below, run:
-- SELECT id FROM cards WHERE title = 'Happy Birthday Sarah!';

-- Sample participant invitation
INSERT INTO participants (
    id,
    card_id,
    invite_token,
    email,
    status
) VALUES (
    gen_random_uuid(),
    'YOUR_CARD_UUID_HERE'::uuid, -- Replace with actual card ID from above
    'test-invite-token-123',
    'friend@example.com',
    'invited'
);
*/

-- ============================================================================
-- QUICK SETUP SCRIPT
-- ============================================================================
-- After creating your first user, run this to create a test card:
/*
DO $$
DECLARE
    test_user_id uuid;
    test_card_id uuid;
BEGIN
    -- Get the first user (for development only!)
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;

    IF test_user_id IS NULL THEN
        RAISE EXCEPTION 'No users found. Create a user first via your app.';
    END IF;

    -- Create a test card
    INSERT INTO cards (host_id, title, recipient_name, occasion, status)
    VALUES (test_user_id, 'Test Birthday Card', 'Test Recipient', 'birthday', 'collecting')
    RETURNING id INTO test_card_id;

    -- Create some test participants
    INSERT INTO participants (card_id, invite_token, email, status)
    VALUES
        (test_card_id, 'invite-token-1', 'friend1@example.com', 'invited'),
        (test_card_id, 'invite-token-2', 'friend2@example.com', 'invited'),
        (test_card_id, 'invite-token-3', 'friend3@example.com', 'viewed');

    RAISE NOTICE 'Created test card % for user %', test_card_id, test_user_id;
END $$;
*/
