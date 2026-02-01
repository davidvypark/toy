# Summary: 01-07 Wire & Verify Foundation

## What Was Built

Wired together all foundation components into a working app with themed UI and Apple Sign-In authentication flow.

### Key Deliverables

1. **Auth ViewModel** (`TOY/Features/Auth/AuthViewModel.swift`)
   - @Observable @MainActor for SwiftUI reactivity
   - Apple Sign-In with nonce generation and SHA256 hashing
   - Auth state management (unknown, signedOut, signedIn)
   - CryptoKit integration for secure nonce handling

2. **Login View** (`TOY/Features/Auth/LoginView.swift`)
   - SignInWithAppleButton with proper styling
   - Adapts to light/dark mode
   - Error message display
   - Loading state indicator

3. **Home View** (`TOY/Features/Home/HomeView.swift`)
   - Welcome message with user's display name
   - Card creation placeholder for Phase 4
   - Sign out functionality

4. **App Entry Point** (`TOY/TOYApp.swift`)
   - ThemeManager environment injection
   - AuthViewModel state initialization
   - Auth state check on launch

5. **Content View** (`TOY/ContentView.swift`)
   - Root navigation based on auth state
   - Animated transitions between states

### Deviation from Original Plan

**Original**: Email/password authentication
**Actual**: Apple Sign-In

Rationale: User requested Apple Sign-In to capture user's name and avoid SMS costs. Apple Sign-In also provides better UX for iOS-native apps.

Changes made:
- Removed email/password fields from AuthViewModel
- Replaced LoginView form with SignInWithAppleButton
- Deleted SignUpView.swift (not needed with Apple Sign-In)
- Added nonce generation and SHA256 hashing for security
- Updated AuthServiceProtocol to use signInWithApple method
- Created Ruby script for generating Apple client secret JWT

### Backend Configuration

- Apple Developer: App ID, Service ID, and Key configured
- Supabase: Apple provider enabled with:
  - Service ID: `com.kindauseful.TOY.auth`
  - Authorized Client ID: `com.kindauseful.TOY` (iOS bundle ID)
  - JWT client secret from .p8 key
- Database: `profiles` table with auto-create trigger on user signup

## Verification

All Phase 1 success criteria verified:

| Criteria | Status |
|----------|--------|
| App launches with themed UI (DM Serif Display visible) | ✓ |
| Supabase authentication flow works (sign in, sign out) | ✓ |
| Database schema exists for cards, clips, participants | ✓ |
| Shared TOYShared Swift Package compiles | ✓ |
| Reusable button, label, input components render correctly | ✓ |

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| AUTH-003 | Apple Sign-In instead of email/password | Captures user name, no SMS costs, better iOS UX |
| AUTH-004 | Nonce-based security for Apple tokens | Required by Apple/Supabase for token validation |

## Files Changed

- `TOY/Features/Auth/AuthViewModel.swift` - Created (Apple Sign-In)
- `TOY/Features/Auth/LoginView.swift` - Created (Apple button)
- `TOY/Features/Home/HomeView.swift` - Created
- `TOY/TOYApp.swift` - Updated with auth flow
- `TOY/ContentView.swift` - Updated as root navigator
- `scripts/generate-apple-secret.rb` - Created for JWT generation

## Time Spent

~45 minutes (including Apple developer/Supabase configuration and troubleshooting)
