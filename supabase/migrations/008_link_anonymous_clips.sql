-- Migration: Link anonymous App Clip user clips to authenticated account
--
-- When a user records via App Clip (anonymous auth) then later signs in with
-- Apple in the main app, this function reassigns their clips to the
-- authenticated account and cleans up the anonymous user.

CREATE OR REPLACE FUNCTION link_anonymous_clips(anon_ids UUID[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    anon_id UUID;
    total_clips INT := 0;
    batch_clips INT;
BEGIN
    -- Must be authenticated
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    FOREACH anon_id IN ARRAY anon_ids LOOP
        -- Skip self-linking
        IF anon_id = current_user_id THEN
            CONTINUE;
        END IF;

        -- Skip if anonymous profile doesn't exist (already cleaned up)
        IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = anon_id) THEN
            CONTINUE;
        END IF;

        -- Reassign clips from anonymous user to authenticated user
        UPDATE clips
        SET participant_id = current_user_id
        WHERE participant_id = anon_id;

        GET DIAGNOSTICS batch_clips = ROW_COUNT;
        total_clips := total_clips + batch_clips;

        -- Handle duplicate participant records (same card_id + both users)
        DELETE FROM participants
        WHERE user_id = anon_id
        AND card_id IN (
            SELECT card_id FROM participants WHERE user_id = current_user_id
        );

        -- Reassign remaining participant records
        UPDATE participants
        SET user_id = current_user_id
        WHERE user_id = anon_id;

        -- Clean up anonymous profile (cascade from auth.users handles profiles)
        DELETE FROM auth.users WHERE id = anon_id;
    END LOOP;

    RETURN json_build_object('linked_clips', total_clips);
END;
$$;

-- Only authenticated users can call this function
GRANT EXECUTE ON FUNCTION link_anonymous_clips(UUID[]) TO authenticated;
