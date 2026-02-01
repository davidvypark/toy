# Codebase Structure

**Analysis Date:** 2026-02-01

## Directory Layout

```
TOY/                                    # Root project directory
├── TOY/                                # Main application source code
│   ├── TOYApp.swift                    # App entry point and scene setup
│   ├── ContentView.swift               # Primary UI view
│   ├── Assets.xcassets/                # Image, color, and icon assets
│   │   ├── AppIcon.appiconset/        # Application icons (iOS, watch, etc.)
│   │   ├── AccentColor.colorset/      # App accent color definitions
│   │   └── Contents.json               # Asset catalog metadata
│   └── Preview Content/                # Preview-only assets
│       └── Preview Assets.xcassets/   # Assets used in Xcode canvas
├── TOYTests/                           # Unit tests
│   └── TOYTests.swift                  # Unit test suite
├── TOYUITests/                         # UI/Integration tests
│   ├── TOYUITests.swift               # UI test cases
│   └── TOYUITestsLaunchTests.swift    # Launch performance tests
├── TOY.xcodeproj/                      # Xcode project configuration
│   ├── project.pbxproj                # Build configuration and file references
│   ├── project.xcworkspace/           # Workspace configuration
│   └── xcuserdata/                    # User-specific Xcode settings
└── .planning/                          # GSD planning and analysis documents
    └── codebase/                       # Codebase documentation
```

## Directory Purposes

**TOY/ (Source):**
- Purpose: Core application source code and resources
- Contains: Swift source files, SwiftUI views, asset catalogs
- Key files: `TOYApp.swift`, `ContentView.swift`, `Assets.xcassets/`

**TOYTests/ (Unit Tests):**
- Purpose: Swift Testing framework unit tests
- Contains: Test suites using `@Test` macro and async/await
- Key files: `TOYTests.swift`

**TOYUITests/ (UI Tests):**
- Purpose: XCTest-based UI and integration tests
- Contains: XCTest classes, launch performance metrics, UI automation
- Key files: `TOYUITests.swift`, `TOYUITestsLaunchTests.swift`

**Assets.xcassets/ (Resource Catalog):**
- Purpose: Centralized asset management for images, colors, icons
- Contains: Appiconset, colorsets, image assets with multiple resolutions
- Key files: `AppIcon.appiconset/`, `AccentColor.colorset/`, `Contents.json`

**Preview Content/ (Development Assets):**
- Purpose: Assets used exclusively in Xcode canvas previews
- Contains: Preview-only images and resources
- Key files: `Preview Assets.xcassets/`

**TOY.xcodeproj/ (Build Configuration):**
- Purpose: Xcode project structure and build configuration
- Contains: Project references, build phases, target definitions
- Key files: `project.pbxproj`, workspace configuration

## Key File Locations

**Entry Points:**
- `TOY/TOYApp.swift`: Main application struct with `@main` decorator - launches first
- `TOY/ContentView.swift`: Root view content

**Configuration:**
- `TOY.xcodeproj/project.pbxproj`: Build settings, target dependencies, file references

**Core Logic:**
- `TOY/ContentView.swift`: UI layout and presentation (lines 10-20)
- `TOY/TOYApp.swift`: Scene and window group setup (lines 11-16)

**Testing:**
- `TOYTests/TOYTests.swift`: Unit tests using Swift Testing framework
- `TOYUITests/TOYUITests.swift`: UI tests with XCTest
- `TOYUITests/TOYUITestsLaunchTests.swift`: Launch performance measurements

## Naming Conventions

**Files:**
- Pattern: `PascalCase.swift` for view and app files
- Examples: `TOYApp.swift`, `ContentView.swift`, `TOYTests.swift`

**Directories:**
- Pattern: `PascalCase` for source modules
- Examples: `TOY/`, `TOYTests/`, `TOYUITests/`
- Pattern: `dotfiles` for configuration
- Examples: `.planning/`, `.git/`

**Asset Catalogs:**
- Pattern: `filename.xcassets/` with `Contents.json` metadata
- Examples: `Assets.xcassets/`, `AppIcon.appiconset/`, `AccentColor.colorset/`

**Swift Structs:**
- Pattern: `PascalCase` for struct names matching file names
- Examples: `struct TOYApp`, `struct ContentView`, `struct TOYTests`

## Where to Add New Code

**New Feature View:**
- Primary code: Create `NewFeatureView.swift` in `TOY/` directory
- Tests: Create test method in `TOYTests/TOYTests.swift` using `@Test` macro
- UI Tests: Add test class method to `TOYUITests/TOYUITests.swift`

**New Component/Module:**
- Implementation: Create file in `TOY/` (e.g., `ComponentName.swift`)
- Pattern: Define as `struct ComponentName: View`
- Export: Use barrel pattern or direct imports from root

**Utilities/Helpers:**
- Shared helpers: Create `Utilities.swift` or `Extensions.swift` in `TOY/`
- Namespace: Use struct with static methods for utility grouping

**New Assets:**
- Colors: Add to `TOY/Assets.xcassets/AccentColor.colorset/` or create new colorset
- Images: Create new imageset in `TOY/Assets.xcassets/`
- Icons: Update `TOY/Assets.xcassets/AppIcon.appiconset/Contents.json` with asset references

## Special Directories

**Assets.xcassets/:**
- Purpose: Xcode asset catalog for resource management
- Generated: Metadata (Contents.json) auto-generated by Xcode
- Committed: All asset files and Contents.json committed to git

**Preview Content/:**
- Purpose: Development-only preview assets for Xcode canvas
- Generated: Metadata auto-generated by Xcode
- Committed: Committed to git for team development

**TOY.xcodeproj/xcuserdata/:**
- Purpose: User-specific Xcode workspace settings and schemes
- Generated: Automatically created by Xcode
- Committed: Not committed (in .gitignore)

**.planning/:**
- Purpose: GSD planning and codebase analysis documentation
- Generated: Created by GSD mapper/planner tools
- Committed: Should be committed for team reference

---

*Structure analysis: 2026-02-01*
