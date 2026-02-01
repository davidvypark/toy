# Coding Conventions

**Analysis Date:** 2026-02-01

## Naming Patterns

**Files:**
- PascalCase with `.swift` extension (e.g., `TOYApp.swift`, `ContentView.swift`)
- File names match the primary struct/class they contain
- Test files use PascalCase with `Tests` suffix (e.g., `TOYTests.swift`, `TOYUITests.swift`)

**Types (Structs/Classes):**
- PascalCase for all type names (e.g., `TOYApp`, `ContentView`, `TOYTests`, `TOYUITests`)
- Struct names are descriptive and single-word or compound (e.g., `ContentView`)
- Test classes use `final class` modifier

**Functions/Methods:**
- camelCase for all function and method names (e.g., `setUpWithError()`, `testExample()`, `testLaunchPerformance()`)
- Test methods prefixed with `test` keyword
- Setup/teardown methods follow naming convention: `setUpWithError()`, `tearDownWithError()`
- Async test methods use `async throws` signature

**Variables:**
- camelCase for variable and property names (e.g., `continueAfterFailure`)
- System framework calls use camelCase (e.g., `app.launch()`)

**Constants:**
- Enum cases use camelCase with Swift naming conventions

## Code Style

**Formatting:**
- 4-space indentation (Swift convention)
- Standard Apple spacing and brace placement
- SwiftUI view structure uses method chaining with newlines for modifiers
- No explicit configuration file detected; follows Xcode defaults

**Access Control:**
- `@main` attribute used for app entry point
- `final` keyword used for test classes
- Views use `struct` by default (value types)
- App entry point uses `@main` struct annotation

## Import Organization

**Order:**
1. System framework imports (e.g., `import SwiftUI`, `import XCTest`, `import Testing`)
2. Internal module imports with `@testable` when in test targets

**Example:**
```swift
import Testing
@testable import TOY
```

**Current usage:**
- SwiftUI imported in UI source files (`TOYApp.swift`, `ContentView.swift`)
- Testing framework imported in unit tests (`TOYTests.swift`)
- XCTest imported in UI tests (`TOYUITests.swift`, `TOYUITestsLaunchTests.swift`)

## Error Handling

**Patterns:**
- Methods that can fail use `throws` keyword
- Test setup/teardown methods explicitly declare `throws`: `override func setUpWithError() throws`
- Error handling delegated to XCTest/Testing framework for test methods
- No custom error types defined yet

**Async/Await:**
- Async test methods use `async throws` signature (e.g., `@Test func example() async throws`)
- Main thread operations marked with `@MainActor` attribute

## Logging

**Framework:** Not explicitly detected. Standard pattern would use:
- `print()` for basic debugging (not observed in current code)
- Xcode console output via test assertions

**Patterns:**
- No logging implementation currently visible
- Test framework handles error/failure reporting

## Comments

**When to Comment:**
- File headers include:
  - `//`
  - `//  [FileName].swift`
  - `//  [ProjectName]`
  - `//`
  - `//  Created by [Author] on [Date].`
  - `//`

**JSDoc/TSDoc:**
- Not used in Swift (not applicable language feature)
- Swift uses inline documentation comments starting with `///` (not currently used)

**Example observed:**
```swift
//
//  TOYApp.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//
```

## Function Design

**Size:** Not specified by convention. Observed functions are concise (3-20 lines).

**Parameters:**
- No parameters observed in current simple codebase
- Methods override parent declarations with exact signature matching

**Return Values:**
- View-returning functions in SwiftUI return `some View`
- Test methods return `Void` (implicit)
- Async test methods use `async throws` for error propagation

**SwiftUI Pattern:**
```swift
var body: some View {
    VStack { }
}
```

## Module Design

**Exports:**
- No explicit access control modifiers on top-level types
- All types implicitly internal to module
- `@testable import` allows test access to internal API

**Barrel Files:** Not used (not Swift pattern)

**View Composition:**
- Views use `#Preview` macro for live previews in Xcode
- Structural organization via nested `VStack`, `HStack` for layout

---

*Convention analysis: 2026-02-01*
