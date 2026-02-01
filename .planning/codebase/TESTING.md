# Testing Patterns

**Analysis Date:** 2026-02-01

## Test Framework

**Primary Framework:**
- Apple Testing framework (swift-testing) - New async/await native testing
  - Used in unit tests
  - Config: Xcode project built-in target `TOYTests`

**Secondary Framework:**
- XCTest - Legacy Apple testing framework
  - Used in UI tests
  - Config: Xcode project built-in targets `TOYUITests`

**Test Structure:**
```
TOYTests/
├── TOYTests.swift           # Unit tests using swift-testing @Test macro

TOYUITests/
├── TOYUITests.swift         # UI tests with XCTestCase
└── TOYUITestsLaunchTests.swift # Launch performance & screenshot tests
```

**Run Commands:**
```bash
xcodebuild test -scheme TOY -testPlan TOY                    # Run all tests
xcodebuild test -scheme TOY -only-testing TOYTests           # Run unit tests only
xcodebuild test -scheme TOY -only-testing TOYUITests         # Run UI tests only
xcodebuild test -scheme TOY -only-testing TOYUITests/TOYUITestsLaunchTests # Launch tests only
```

## Test File Organization

**Location:**
- Co-located in separate test targets (standard Xcode organization)
- Unit tests: `TOYTests/` directory
- UI tests: `TOYUITests/` directory
- Source code: `TOY/` directory

**Naming:**
- Test files: `[TargetName]Tests.swift` (e.g., `TOYTests.swift`)
- Test targets: `[AppName]Tests` (e.g., `TOYTests`)
- Test classes: `[Purpose]Tests` or `[Purpose]UITests`

## Test Structure

**Unit Test Pattern (swift-testing):**

Located in `TOYTests/TOYTests.swift`:
```swift
import Testing
@testable import TOY

struct TOYTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
}
```

**Key characteristics:**
- Struct-based (not class-based) using swift-testing
- Uses `@Test` macro for test methods
- Methods are async by default with `async throws` signature
- Uses `#expect()` macro for assertions (not XCTAssert)
- Supports parallel test execution via async/await

**UI Test Pattern (XCTest):**

Located in `TOYUITests/TOYUITests.swift`:
```swift
import XCTest

final class TOYUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Teardown code
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        // Assertions with XCTAssert variants
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

**Key characteristics:**
- Class-based extending `XCTestCase`
- Setup/teardown via `setUpWithError()` and `tearDownWithError()`
- Methods marked with `@MainActor` for thread safety
- Uses `XCTAssert*` family for assertions
- Performance testing with `measure()` and metrics
- `continueAfterFailure = false` stops tests on first failure

**Launch Performance Test Pattern:**

Located in `TOYUITests/TOYUITestsLaunchTests.swift`:
```swift
import XCTest

final class TOYUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

**Key characteristics:**
- Runs for each target application UI configuration via override
- Captures screenshots as test attachments
- Attachments kept for debugging and documentation
- Tests initial app launch behavior

## Assertion Patterns

**swift-testing (Unit Tests):**
```swift
#expect(condition)              // Basic expectation check
#expect(value == expected)      // Equality check
```

**XCTest (UI Tests):**
```swift
XCTAssert(condition)
XCTAssertEqual(actual, expected)
XCTAssertTrue(condition)
XCTAssertFalse(condition)
XCTAssertNil(value)
XCTAssertNotNil(value)
```

## Async Testing

**swift-testing Pattern:**
```swift
@Test func example() async throws {
    // async/await native - no need for expectation objects
    // Direct async function calls supported
}
```

**XCTest Pattern:**
```swift
@MainActor
func testExample() throws {
    // Main thread guaranteed via @MainActor
    // For async operations, use XCTestExpectation (if needed)
}
```

## UI Automation Pattern

**Standard XCTest UI Automation:**
```swift
let app = XCUIApplication()
app.launch()

// Access UI elements
let button = app.buttons["buttonIdentifier"]
button.tap()

// Verify state
XCTAssertTrue(app.staticTexts["expectedText"].exists)
```

## Mocking

**Framework:** Not explicitly used in current codebase

**What NOT to Mock:**
- SwiftUI View rendering (test behavior, not layout)
- XCUIApplication launches (test actual app)
- View composition (integration test instead)

**What to Mock (when needed):**
- Network requests
- User defaults/preferences
- File system operations
- External services

## Test Coverage

**Requirements:** Not enforced in current configuration

**View Coverage:**
- `#Preview` macro used for manual preview-based testing in Xcode
- Not automated coverage collection

**Current Coverage:**
- Basic example tests provided as templates
- No meaningful assertions yet
- UI launch and performance test structure in place

## Special Test Features

**@MainActor Annotation:**
- Ensures test runs on main thread
- Required for UI test methods
- Prevents race conditions in async code

**Metrics Support:**
- `XCTApplicationLaunchMetric()` measures app launch time
- Performance tests use `measure()` with metrics
- Results available in Xcode test report

**Screenshot Attachments:**
- `XCTAttachment(screenshot: app.screenshot())` captures UI state
- Attached to test results for debugging
- Lifetime `.keepAlways` preserves for analysis

**Preview Testing:**
- SwiftUI `#Preview` macro allows live canvas testing
- Real-time feedback during development
- Located: `ContentView.swift` line 22-24

---

*Testing analysis: 2026-02-01*
