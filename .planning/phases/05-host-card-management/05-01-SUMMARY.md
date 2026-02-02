---
phase: 05-host-card-management
plan: 01
subsystem: services
tags: [supabase, storage, swiftui, crud, ios]

# Dependency graph
requires:
  - phase: 04-host-card-creation
    provides: CardService actor with createCard, createClip, fetchCardsForHost
provides:
  - fetchParticipantsForCard method for querying participants
  - fetchClipsForCard method for querying clips
  - deleteClip method for storage and database cleanup
  - ParticipantRow UI component for participant status display
affects: [05-02-card-detail-view, 05-03-clip-management]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Storage-first delete pattern (delete file, then record)"
    - "Status mapping computed properties in SwiftUI views"

key-files:
  created:
    - TOY/Features/CardManagement/ParticipantRow.swift
  modified:
    - TOY/TOYShared/Sources/TOYShared/Services/CardService.swift

key-decisions:
  - "CLIP-003: Delete storage file before database record to prevent orphaned files"
  - "UI-006: Status mapping via computed properties for clean view code"

patterns-established:
  - "Storage-first delete: Remove storage file first, continue even if fails (file may be already deleted), then delete DB record"
  - "Status computed properties: Map enum/string status to user-facing text and colors in view"

# Metrics
duration: 3min
completed: 2026-02-02
---

# Phase 5 Plan 1: CardService Extensions & ParticipantRow Summary

**CardService extended with participant/clip fetch and clip delete operations, plus ParticipantRow component for participant status display**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-02T08:49:34Z
- **Completed:** 2026-02-02T08:52:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- CardService can now fetch all participants for a card
- CardService can now fetch all clips for a card ordered by position
- CardService can delete clips with storage cleanup (storage first, then database)
- ParticipantRow displays participant status with visual indicators

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend CardService with fetch and delete methods** - `9d400eb` (feat)
2. **Task 2: Create ParticipantRow component** - `abc6b64` (feat)

## Files Created/Modified
- `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` - Added fetchParticipantsForCard, fetchClipsForCard, deleteClip methods + CardError.deleteFailed case
- `TOY/Features/CardManagement/ParticipantRow.swift` - New UI component for displaying participant status in lists

## Decisions Made
- **CLIP-003:** Delete storage file before database record - prevents orphaned files if DB delete fails; continues if storage delete fails (file may already be deleted)
- **UI-006:** Use computed properties for status text and color mapping - keeps view body clean and logic testable

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- CardService ready for use in CardDetailView (Plan 05-02)
- ParticipantRow ready for use in participant list within CardDetailView
- All three new methods follow existing patterns and compile successfully

---
*Phase: 05-host-card-management*
*Completed: 2026-02-02*
