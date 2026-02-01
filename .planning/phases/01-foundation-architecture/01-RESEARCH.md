# Phase 1: Foundation & Architecture - Research

**Researched:** 2026-02-01
**Domain:** iOS SwiftUI Architecture, Swift Packages, Supabase Integration, Design System
**Confidence:** HIGH

## Summary

This phase establishes the technical foundation for TOY: clean MVVM architecture with @Observable (iOS 17+), a shared Swift package for App Clip code reuse, Supabase backend integration, reusable UI components, and a theme system supporting dark/light mode.

The project starts from a fresh Xcode project with basic SwiftUI template code (`TOYApp.swift`, `ContentView.swift`). This phase transforms it into a well-architected foundation with proper separation of concerns.

**Key discoveries:**
- @Observable (iOS 17+) replaces @ObservableObject/@Published with simpler, more performant code
- Local Swift packages are the standard way to share code between main app and App Clip targets
- supabase-swift v2.41.0 provides full async/await support for auth and database
- App Clip size limits: 15MB for physical invocation (QR/NFC), 50-100MB for digital (iOS 17+)
- @MainActor should be applied to entire ViewModel classes for Swift 6 compatibility

**Primary recommendation:** Create TOYShared Swift package first, then build architecture layers on top.

## Standard Stack

The established libraries/tools for this phase:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Native, mature, required for @Observable |
| @Observable | iOS 17+ | State management | Replaces @ObservableObject, less boilerplate |
| supabase-swift | 2.41.0 | Backend SDK | Official Swift SDK, full async/await support |
| Swift Package Manager | Built-in | Dependency management & code sharing | Apple's first-party solution, integrated with Xcode |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NavigationStack | iOS 16+ | Type-safe navigation | All navigation, replaces NavigationView |
| @Environment | Built-in | Dependency injection | Injecting services into views |
| @Entry macro | Xcode 16+ | Custom environment values | Simplifies environment key boilerplate |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @Observable | @ObservableObject | Legacy, more boilerplate, works on iOS 14+ |
| Local Swift Package | Shared Framework | Packages simpler, better SPM integration |
| @Environment DI | Swift-Dependencies | Third-party adds complexity, better for complex DI |
| MVVM | TCA | TCA adds 2-3MB binary, more ceremony for this app size |

**Installation:**
```swift
// Package.swift in TOYShared
let package = Package(
    name: "TOYShared",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TOYShared", targets: ["TOYShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "TOYShared",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        .testTarget(name: "TOYSharedTests", dependencies: ["TOYShared"]),
    ]
)
```

## Architecture Patterns

### Recommended Project Structure

```
TOY/
├── TOY.xcodeproj
├── TOYShared/                    # Local Swift Package
│   ├── Package.swift
│   ├── Sources/
│   │   └── TOYShared/
│   │       ├── Models/
│   │       │   ├── Card.swift
│   │       │   ├── Clip.swift
│   │       │   └── User.swift
│   │       ├── Services/
│   │       │   ├── SupabaseService.swift
│   │       │   └── AuthService.swift
│   │       ├── Theme/
│   │       │   ├── ThemeManager.swift
│   │       │   ├── Colors.swift
│   │       │   └── Typography.swift
│   │       └── Components/
│   │           ├── TOYButton.swift
│   │           ├── TOYTextField.swift
│   │           └── TOYLabel.swift
│   └── Tests/
├── TOY/                          # Main App Target
│   ├── TOYApp.swift
│   ├── Features/
│   │   └── ...
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Fonts/
│   └── Info.plist
├── TOYClip/                      # App Clip Target (future phase)
│   ├── TOYClipApp.swift
│   └── ...
└── TOYTests/
```

### Pattern 1: @Observable ViewModel with @MainActor

**What:** ViewModels using @Observable macro with MainActor isolation for thread-safe UI updates
**When to use:** Every ViewModel that manages state consumed by views

```swift
// Source: Swift by Sundell, Hacking with Swift, Swift Forums
@Observable @MainActor
final class CardViewModel {
    // State
    var cards: [Card] = []
    var isLoading = false
    var errorMessage: String?

    // Dependencies
    private let cardService: CardServiceProtocol

    init(cardService: CardServiceProtocol) {
        self.cardService = cardService
    }

    func loadCards() async {
        isLoading = true
        defer { isLoading = false }

        do {
            cards = try await cardService.fetchCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Usage in View
struct CardListView: View {
    @State private var viewModel = CardViewModel(cardService: SupabaseCardService())

    var body: some View {
        List(viewModel.cards) { card in
            Text(card.title)
        }
        .task {
            await viewModel.loadCards()
        }
    }
}
```

### Pattern 2: Protocol-Based Service Layer

**What:** Services defined by protocols, implementations injected via Environment
**When to use:** All external service interactions (Supabase, etc.)

```swift
// Source: Modern MVVM patterns, SwiftLee
// Protocol definition
protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws
    var currentUser: User? { get async }
}

// Implementation
final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(email: email, password: password)
        return User(from: response.user)
    }
    // ...
}

// Environment key using @Entry (Xcode 16+)
extension EnvironmentValues {
    @Entry var authService: AuthServiceProtocol = SupabaseAuthService(client: supabase)
}

// Usage
struct LoginView: View {
    @Environment(\.authService) private var authService
    // ...
}
```

### Pattern 3: Theme System with Color Scheme Support

**What:** Centralized theme manager supporting system, light, and dark modes
**When to use:** All color and typography decisions

```swift
// Source: SwiftUI Handbook, Medium articles on theme systems
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class ThemeManager {
    @AppStorage("selectedTheme") var selectedTheme: AppTheme = .system

    var colorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }
}

// Colors with automatic dark/light adaptation
extension Color {
    static let toyPrimary = Color("TOYPrimary")      // Asset catalog
    static let toyBackground = Color("TOYBackground")
    static let toyText = Color("TOYText")
}

// Apply at root
@main
struct TOYApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
                .environment(themeManager)
        }
    }
}
```

### Pattern 4: Reusable UI Components

**What:** Encapsulated UI components with consistent styling
**When to use:** Buttons, text fields, labels, and other repeated UI elements

```swift
// Source: DEV Community component library guide, Kodeco
struct TOYButton: View {
    enum Style {
        case primary
        case secondary
        case text
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("DMSerifDisplay-Regular", size: 16, relativeTo: .body))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(8)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .toyPrimary
        case .secondary: return .clear
        case .text: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary, .text: return .toyPrimary
        }
    }
}
```

### Pattern 5: Supabase Client Singleton

**What:** Single Supabase client instance shared across app
**When to use:** All Supabase operations

```swift
// Source: Supabase official docs
// Supabase.swift in TOYShared
import Supabase

public let supabase = SupabaseClient(
    supabaseURL: URL(string: Configuration.supabaseURL)!,
    supabaseKey: Configuration.supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: .init(flowType: .pkce),
        global: .init(
            headers: ["x-app-version": Configuration.appVersion]
        )
    )
)

// Configuration.swift
enum Configuration {
    static var supabaseURL: String {
        // Load from environment or plist
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    static var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
```

### Anti-Patterns to Avoid

- **@ObservableObject/@Published**: Deprecated for iOS 17+; use @Observable instead
- **NavigationView**: Deprecated; use NavigationStack
- **Global mutable state**: Use Environment for dependency injection, not singletons for services
- **Combine for simple state**: @Observable handles view state; Combine only for complex async streams
- **Mixed architecture**: Don't mix UIKit patterns (coordinators, delegates) unless necessary
- **Fat ViewModels**: Keep ViewModels focused; extract reusable logic to services

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State observation | Custom observation | @Observable macro | Compiler-generated, optimized |
| Theme persistence | UserDefaults wrapper | @AppStorage | SwiftUI native, reactive |
| Color scheme detection | Manual trait checks | @Environment(\.colorScheme) | Automatic, reactive |
| Custom environment values | Full EnvironmentKey boilerplate | @Entry macro (Xcode 16+) | One line vs. 10 lines |
| Auth state management | Custom auth manager | Supabase SDK auth.onAuthStateChange | Handles edge cases, tokens |
| Signed URLs | Manual URL building | supabase.storage.createSignedUrl | Handles expiration, security |

**Key insight:** iOS 17+ and Xcode 16+ have significantly reduced boilerplate. Use the new macros (@Observable, @Entry) rather than the legacy patterns.

## Common Pitfalls

### Pitfall 1: Forgetting @MainActor on ViewModels

**What goes wrong:** Swift 6 strict concurrency errors; UI updates on background thread crash
**Why it happens:** @Observable doesn't require @MainActor, but async operations do for UI safety
**How to avoid:** Always mark @Observable ViewModels with @MainActor
**Warning signs:** "Cannot mutate property from non-isolated context" errors

```swift
// Bad - will cause issues in Swift 6
@Observable class MyViewModel {
    var data: [Item] = []
    func load() async {
        data = try await service.fetch() // ❌ Not main-actor isolated
    }
}

// Good
@Observable @MainActor
final class MyViewModel {
    var data: [Item] = []
    func load() async {
        data = try await service.fetch() // ✅ Safe
    }
}
```

### Pitfall 2: App Clip Size Explosion

**What goes wrong:** App Clip exceeds 15MB limit, rejected from App Store
**Why it happens:** Including unnecessary assets, frameworks, or analytics in App Clip target
**How to avoid:**
- Measure thinned binary size regularly
- Only include essential components from TOYShared
- Use SF Symbols instead of custom icons where possible
- Use conditional compilation (#if !APPCLIP)
**Warning signs:** Xcode archive size growing, supabase-swift alone is ~2-3MB

### Pitfall 3: Not Using Asset Catalogs for Theme Colors

**What goes wrong:** Colors don't adapt to dark mode, or require manual checking
**Why it happens:** Using hardcoded Color() instead of named colors from asset catalog
**How to avoid:** Define all colors in Assets.xcassets with dark mode variants
**Warning signs:** Manual colorScheme checks everywhere, inconsistent dark mode

### Pitfall 4: Circular Package Dependencies

**What goes wrong:** Swift Package fails to compile, or creates implicit dependencies
**Why it happens:** TOYShared imports something that depends on TOYShared
**How to avoid:** Keep TOYShared dependency-free except for external packages (Supabase)
**Warning signs:** "Circular dependency" errors, unexpected rebuilds

### Pitfall 5: Supabase Client Created Multiple Times

**What goes wrong:** Multiple auth states, inconsistent database connections, wasted memory
**Why it happens:** Creating new SupabaseClient in each ViewModel or service
**How to avoid:** Single `let supabase` global in TOYShared, accessed everywhere
**Warning signs:** Auth state not syncing, multiple network connections

### Pitfall 6: Custom Fonts Not Scaling with Dynamic Type

**What goes wrong:** Text doesn't respond to accessibility settings, poor accessibility
**Why it happens:** Using `.font(.custom("Font", size: 24))` without `relativeTo:`
**How to avoid:** Always use `relativeTo:` parameter for accessibility scaling
**Warning signs:** App fails accessibility audits, complaints from users with visual impairments

```swift
// Bad
.font(.custom("DMSerifDisplay-Regular", size: 24))

// Good
.font(.custom("DMSerifDisplay-Regular", size: 24, relativeTo: .title))
```

## Code Examples

### Supabase Database Query

```swift
// Source: Supabase Swift docs
// Fetch all cards for current user
func fetchCards() async throws -> [Card] {
    try await supabase
        .from("cards")
        .select()
        .eq("host_id", value: currentUserId)
        .order("created_at", ascending: false)
        .execute()
        .value
}

// Insert a new card
func createCard(_ card: Card) async throws -> Card {
    try await supabase
        .from("cards")
        .insert(card)
        .select()
        .single()
        .execute()
        .value
}
```

### Supabase Authentication

```swift
// Source: Supabase Swift docs
// Email/password sign up
func signUp(email: String, password: String) async throws {
    try await supabase.auth.signUp(email: email, password: password)
}

// Sign in
func signIn(email: String, password: String) async throws {
    try await supabase.auth.signIn(email: email, password: password)
}

// Get current user
func getCurrentUser() async throws -> User? {
    try await supabase.auth.session?.user
}

// Listen to auth changes
func observeAuthState() -> AsyncStream<AuthState> {
    AsyncStream { continuation in
        let subscription = supabase.auth.onAuthStateChange { event, session in
            continuation.yield(AuthState(event: event, session: session))
        }
        continuation.onTermination = { _ in
            subscription.cancel()
        }
    }
}
```

### Typography Setup with Custom Fonts

```swift
// Source: Kodeco, Sarunw, Apple docs
// Typography.swift in TOYShared
import SwiftUI

public extension Font {
    // DM Serif Display for headings
    static func toyTitle(_ size: CGFloat = 28) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .title)
    }

    static func toyHeadline(_ size: CGFloat = 20) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: .headline)
    }

    // System font for body text (better readability)
    static func toyBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, design: .rounded).weight(.regular)
    }

    static func toyCaption(_ size: CGFloat = 12) -> Font {
        .system(size: size, design: .rounded).weight(.medium)
    }
}

// Usage
Text("Welcome to TOY")
    .font(.toyTitle())
```

### Environment-Based Dependency Injection

```swift
// Source: SwiftLee, SwiftUI docs
// EnvironmentKeys.swift
extension EnvironmentValues {
    @Entry var authService: AuthServiceProtocol = SupabaseAuthService(client: supabase)
    @Entry var cardService: CardServiceProtocol = SupabaseCardService(client: supabase)
    @Entry var themeManager: ThemeManager = ThemeManager()
}

// Root app setup
@main
struct TOYApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.themeManager, themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// View usage
struct SomeView: View {
    @Environment(\.authService) private var authService
    @Environment(\.cardService) private var cardService

    var body: some View {
        // Use services...
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| @ObservableObject + @Published | @Observable macro | iOS 17 (2023) | Less boilerplate, better performance |
| NavigationView | NavigationStack | iOS 16 (2022) | Type-safe navigation, programmatic control |
| ObservableObject in ViewModel | @Observable @MainActor | Swift 5.9/6 (2024) | Thread-safe by default |
| EnvironmentKey boilerplate | @Entry macro | Xcode 16 (2024) | One-line environment values |
| Manual theme handling | @AppStorage + preferredColorScheme | iOS 14+ (mature) | Automatic persistence |
| CocoaPods/Carthage | Swift Package Manager | 2019+ (mature) | Apple-native, integrated |

**Deprecated/outdated:**
- @StateObject/@ObservableObject: Use @Observable instead (iOS 17+)
- NavigationView: Use NavigationStack instead
- Combine for simple state: @Observable handles most cases
- Manual DispatchQueue.main: Use @MainActor instead

## Open Questions

Things that couldn't be fully resolved:

1. **Supabase API Key Security**
   - What we know: Anon key is designed to be public; RLS policies protect data
   - What's unclear: Best practice for storing/accessing keys in Swift (Info.plist vs. generated file)
   - Recommendation: Use Info.plist with build-phase script to inject from environment

2. **App Clip Binary Size Budget**
   - What we know: 15MB for physical invocation, 50-100MB for digital (iOS 17+)
   - What's unclear: Exact size of supabase-swift + our code after thinning
   - Recommendation: Set up size monitoring in CI early; target under 10MB to be safe

3. **Optimal Theme Color Organization**
   - What we know: Asset catalog colors work well for simple cases
   - What's unclear: Whether to use semantic naming (primary/secondary) or descriptive (cardBackground)
   - Recommendation: Start with semantic naming, refactor if needed

## Sources

### Primary (HIGH confidence)
- [Supabase Swift SDK GitHub](https://github.com/supabase/supabase-swift) - v2.41.0, installation, API reference
- [Supabase iOS/SwiftUI Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui) - Official setup guide
- [Kodeco App Clips Tutorial](https://www.kodeco.com/14455571-app-clips-for-ios-getting-started) - App Clip architecture patterns
- [Apple Developer Documentation](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages) - Local Swift packages

### Secondary (MEDIUM confidence)
- [SwiftLee - @Environment](https://www.avanderlee.com/swiftui/environment-property-wrapper/) - Environment-based DI patterns
- [Swift by Sundell - MainActor](https://www.swiftbysundell.com/articles/the-main-actor-attribute/) - MainActor best practices
- [Hacking with Swift - Custom Fonts](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-dynamic-type-with-a-custom-font) - Dynamic Type with custom fonts
- [DEV Community - SwiftUI Design System](https://dev.to/swift_pal/swiftui-design-system-a-complete-guide-to-building-consistent-ui-components-2025-299k) - Component library patterns

### Tertiary (LOW confidence)
- Various Medium articles on @Observable patterns - Community patterns, needs verification
- App Clip size limit updates from Twitter/X - Unofficial sources on 100MB limit

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official docs, widely adopted patterns
- Architecture: HIGH - Well-established MVVM with @Observable, verified across sources
- Pitfalls: HIGH - Documented in official forums and verified tutorials
- Code examples: HIGH - Taken from or verified against official documentation

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable domain)

---

## Phase-Specific Implementation Notes

### ARCH-01: Clean Architecture with MVVM Pattern
- Use @Observable @MainActor on all ViewModels
- Protocol-based services for testability
- Environment-based dependency injection
- Clear separation: View -> ViewModel -> Service -> Supabase

### ARCH-02: Reusable UI Component Library
- Create in TOYShared/Sources/TOYShared/Components/
- Start with: TOYButton, TOYTextField, TOYLabel
- All components use theme colors and fonts
- Support Dynamic Type via relativeTo parameter

### ARCH-03: Theme System Supporting Dark/Light Mode
- ThemeManager with @AppStorage for persistence
- Asset catalog colors with dark mode variants
- Apply at root via preferredColorScheme modifier
- DM Serif Display font registered and accessible

### ARCH-04: Shared Swift Package
- Create TOYShared/ as local package
- Include: Models, Services, Theme, Components
- Both main app and App Clip depend on TOYShared
- supabase-swift is dependency of package, not targets

### TECH-01: Supabase Authentication
- Use supabase-swift 2.41.0
- Implement AuthService protocol
- Support email/password and anonymous auth (for App Clip participants)
- Listen to auth state changes with async stream

### TECH-02: Supabase Database
- Tables: users, cards, clips (from project research)
- CardService and ClipService protocols
- Async/await for all database operations
- Row Level Security configured server-side
