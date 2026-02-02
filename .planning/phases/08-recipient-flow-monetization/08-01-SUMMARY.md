---
phase: 08-recipient-flow-monetization
plan: 01
subsystem: web
tags: [nextjs, supabase, tailwind, typescript, vercel]

# Dependency graph
requires:
  - phase: none
    provides: none (greenfield web project)
provides:
  - Next.js 16 project at sendtoycard-web/
  - Supabase server-side client for signed URL generation
  - TOY brand colors and typography configured
  - Project structure ready for /watch/[token] page
affects: [08-02, 08-03, 08-04, 08-05, 08-06]

# Tech tracking
tech-stack:
  added: [next@16.1.6, react@19.2.3, @supabase/supabase-js@2.93.3, tailwindcss@4]
  patterns: [server-side Supabase client, Tailwind v4 CSS-based theme]

key-files:
  created:
    - sendtoycard-web/lib/supabase.ts
    - sendtoycard-web/app/layout.tsx
    - sendtoycard-web/app/page.tsx
    - sendtoycard-web/app/globals.css
    - sendtoycard-web/.env.local.example
  modified: []

key-decisions:
  - "WEB-001: Use Tailwind v4 CSS-based theme configuration (no tailwind.config.ts)"
  - "WEB-002: Server-side Supabase client with service role key for signed URLs"

patterns-established:
  - "CSS custom properties for TOY brand colors (--toy-primary, --toy-background, etc.)"
  - "createServerClient() pattern for server-side Supabase operations"

# Metrics
duration: 4min
completed: 2026-02-02
---

# Phase 8 Plan 1: Next.js Web Project Setup Summary

**Next.js 16 project with Tailwind v4, Supabase JS client, and TOY brand styling at sendtoycard-web/**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-02T13:30:00Z
- **Completed:** 2026-02-02T13:34:00Z
- **Tasks:** 2
- **Files created:** 18

## Accomplishments

- Created Next.js 16 project with TypeScript, Tailwind v4, ESLint, and App Router
- Installed and configured Supabase JS client for server-side operations
- Configured TOY brand colors (coral primary, warm cream background) via CSS custom properties
- Added DM Serif Display font for headings alongside Geist font family
- Created .env.local.example documenting required environment variables

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Next.js project with dependencies** - `71f195b` (feat)
2. **Task 2: Configure Supabase client and root layout** - `889874e` (feat)

## Files Created/Modified

- `sendtoycard-web/package.json` - Project manifest with Next.js 16, React 19, Supabase dependencies
- `sendtoycard-web/lib/supabase.ts` - Server-side Supabase client with service role key
- `sendtoycard-web/app/layout.tsx` - Root layout with TOY metadata and fonts
- `sendtoycard-web/app/page.tsx` - Simple landing page with TOY branding
- `sendtoycard-web/app/globals.css` - TOY brand colors as CSS custom properties with Tailwind v4 theme
- `sendtoycard-web/.env.local.example` - Environment variable documentation
- `sendtoycard-web/.gitignore` - Updated to allow .env.local.example
- `sendtoycard-web/tsconfig.json` - TypeScript configuration
- `sendtoycard-web/next.config.ts` - Next.js configuration
- `sendtoycard-web/postcss.config.mjs` - PostCSS for Tailwind v4

## Decisions Made

### WEB-001: Tailwind v4 CSS-based theme configuration

Next.js 16 ships with Tailwind v4, which uses CSS-based configuration via `@theme inline` in globals.css rather than a JavaScript tailwind.config.ts file. TOY brand colors are defined as CSS custom properties and exposed to Tailwind via `@theme inline`.

### WEB-002: Server-side Supabase client pattern

Created `createServerClient()` function that uses the service role key for elevated permissions. This is required for generating signed URLs from private storage buckets. The function validates environment variables and throws descriptive errors if missing.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

Before deploying to Vercel, the following environment variables must be configured:

1. **SUPABASE_URL** - Get from Supabase Dashboard -> Settings -> API -> Project URL
2. **SUPABASE_SERVICE_KEY** - Get from Supabase Dashboard -> Settings -> API -> service_role key (secret)

See `.env.local.example` for reference.

## Next Phase Readiness

- Project structure ready for /watch/[token] video viewer page (Plan 08-02)
- Supabase client ready for card lookup and signed URL generation
- TOY branding applied, ready for video player component
- Note: Vercel deployment configuration needed before going live

---
*Phase: 08-recipient-flow-monetization*
*Completed: 2026-02-02*
