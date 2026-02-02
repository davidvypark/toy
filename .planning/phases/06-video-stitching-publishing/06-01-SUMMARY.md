---
phase: 06-video-stitching-publishing
plan: 01
subsystem: storage
tags: [supabase, storage, swift, videos, publishing]

# Dependency graph
requires:
  - phase: 03-storage-sharing
    provides: clips bucket pattern, StorageService actor, signed URLs
  - phase: 04-host-card-creation
    provides: CardService actor, card CRUD operations
provides:
  - Videos bucket for final montage storage
  - uploadMontage method for montage upload with upsert
  - createSignedVideoURL for montage access
  - publishCard method with video_url and published_at
affects: [06-02-video-stitching, 06-03-publish-flow, recipient-viewing]

# Tech tracking
tech-stack:
  added: []
  patterns: [upsert-enabled-upload for re-publishing]

key-files:
  created:
    - supabase/migrations/004_videos_bucket.sql
  modified:
    - TOY/TOYShared/Sources/TOYShared/Services/StorageService.swift
    - TOY/TOYShared/Sources/TOYShared/Services/CardService.swift

key-decisions:
  - "VIDEO-001: upsert=true for montage uploads to allow re-publishing"

patterns-established:
  - "Separate bucket for final outputs (videos) vs working files (clips)"
  - "publishCard sets status, video_url, and published_at atomically"

# Metrics
duration: 2min
completed: 2026-02-02
---

# Phase 6 Plan 1: Videos Bucket and Publishing Infrastructure Summary

**Videos bucket with RLS policies, StorageService montage upload/signed URL methods, and CardService publishCard for atomic status+video_url+timestamp updates**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-02T11:08:46Z
- **Completed:** 2026-02-02T11:10:18Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Created videos storage bucket with INSERT/SELECT/UPDATE/DELETE RLS policies for authenticated users
- Extended StorageService with uploadMontage() using upsert=true for re-publishing support
- Extended StorageService with createSignedVideoURL() for montage video access
- Added CardService.publishCard() that atomically updates status, video_url, and published_at

## Task Commits

Each task was committed atomically:

1. **Task 1: Create videos bucket SQL migration** - `8f8cf80` (feat)
2. **Task 2: Extend StorageService for videos bucket** - `3ccb2a7` (feat)
3. **Task 3: Add publishCard method to CardService** - `47cbfc5` (feat)

## Files Created/Modified
- `supabase/migrations/004_videos_bucket.sql` - Videos bucket and RLS policies
- `TOY/TOYShared/Sources/TOYShared/Services/StorageService.swift` - uploadMontage and createSignedVideoURL methods
- `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` - publishCard method

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| VIDEO-001 | upsert=true for montage uploads | Allows re-publishing (overwriting existing montage) without delete+insert |

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

**SQL migration requires manual execution.** Apply via Supabase Dashboard SQL Editor:
1. Open Supabase Dashboard > SQL Editor
2. Paste contents of `supabase/migrations/004_videos_bucket.sql`
3. Execute to create videos bucket and RLS policies
4. Verify bucket appears in Storage section

## Next Phase Readiness
- Videos bucket ready for montage uploads
- StorageService can upload final montage files
- CardService can publish cards with video URLs
- Ready for 06-02 video stitching implementation

---
*Phase: 06-video-stitching-publishing*
*Completed: 2026-02-02*
