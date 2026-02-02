---
phase: 03-data-layer-upload
plan: 02
subsystem: infra
tags: [deep-links, universal-links, ios, entitlements]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: TOYShared Swift Package with Services directory
provides:
  - DeepLinkService for parsing Universal Link URLs
  - Associated Domains entitlement for applinks
  - onOpenURL handler infrastructure in TOYApp
affects: [04-card-playback, phase4-participant-invite, recipient-viewing]

# Tech tracking
tech-stack:
  added: []
  patterns: [deep-link-parsing, onOpenURL-handling]

key-files:
  created:
    - TOY/TOYShared/Sources/TOYShared/Services/DeepLinkService.swift
  modified:
    - TOY/TOY.entitlements
    - TOY/TOYApp.swift

key-decisions:
  - "LINK-001: Placeholder domain toy.app for Associated Domains"

patterns-established:
  - "DeepLinkDestination enum for type-safe navigation destinations"
  - "DeepLinkService.parse() static method for URL parsing"
  - "pendingDeepLink state property for storing parsed destinations"

# Metrics
duration: 2min
completed: 2026-02-02
---

# Phase 3 Plan 02: Deep Link Infrastructure Summary

**Universal Links infrastructure with DeepLinkService URL parser, Associated Domains entitlement, and onOpenURL handler in TOYApp**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-02T06:50:54Z
- **Completed:** 2026-02-02T06:52:54Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- DeepLinkService with DeepLinkDestination enum for type-safe deep link handling
- Associated Domains entitlement configured with applinks:toy.app placeholder
- onOpenURL handler wired in TOYApp with debug logging

## Task Commits

Each task was committed atomically:

1. **Task 1: Create DeepLinkService with URL parsing** - `d0b62fc` (feat)
2. **Task 2: Add Associated Domains entitlement** - `4afa9e9` (feat)
3. **Task 3: Wire onOpenURL handler in TOYApp** - `fe8b738` (feat)

## Files Created/Modified
- `TOY/TOYShared/Sources/TOYShared/Services/DeepLinkService.swift` - URL parsing service with DeepLinkDestination enum
- `TOY/TOY.entitlements` - Added Associated Domains with applinks:toy.app
- `TOY/TOYApp.swift` - Added pendingDeepLink state and onOpenURL handler

## Decisions Made
- **LINK-001:** Using placeholder domain "toy.app" for Associated Domains entitlement. When real domain is finalized, update entitlement and host AASA file at /.well-known/apple-app-site-association

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Deep link parsing ready for invite flow in Phase 4+
- Card share token extraction working for /card/{shareToken} URLs
- Actual navigation to card view will be implemented when card viewing flow exists
- When real domain is chosen, update entitlement and host AASA file

---
*Phase: 03-data-layer-upload*
*Completed: 2026-02-02*
