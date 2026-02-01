# Technology Stack

**Analysis Date:** 2026-02-01

## Languages

**Primary:**
- Swift 5+ - iOS application implementation, UI layer, and business logic

## Runtime

**Environment:**
- iOS 18.2 (Minimum Deployment Target)
- Apple Xcode IDE

**Platform:**
- iOS/iPadOS mobile application
- Built for arm64 architecture (native iOS)

## Frameworks

**Core:**
- SwiftUI - Declarative UI framework for building user interface components
- Xcode Build System - Native project and build management

**Testing:**
- XCTest - Native iOS/macOS unit and UI testing framework
- Swift Testing Framework - Modern async testing via `Testing` module (used in `TOYTests.swift`)

**Build/Dev:**
- Xcode 16+ - IDE and build orchestration

## Key Dependencies

**Critical:**
- SwiftUI framework (built-in) - Core UI rendering and state management for iOS 18.2+

**Testing Dependencies:**
- XCTest framework (built-in) - Used for `TOYUITests` target
- Swift Testing framework (built-in) - Used for unit tests with async support

## Configuration

**Environment:**
- Xcode project-based configuration (`TOY.xcodeproj`)
- Build settings managed via Xcode UI and `project.pbxproj`
- Code signing enabled (Automatic Code Signing)
- Development team identifier: `ZH8H29HA3J`

**Build Settings:**
- Product name: `TOY`
- Marketing version: `1.0`
- Current project version: `1`
- SDK root: `iphoneos`
- Asset catalog compiler enabled with Swift symbol extensions
- Clang C++ language standard: `gnu++20`

**Build Targets:**
- `TOY` - Main app target
- `TOYTests` - Unit test target with test host dependency
- `TOYUITests` - UI test target

## Platform Requirements

**Development:**
- macOS with Xcode 16+ installed
- Swift 5.9+
- Xcode Command Line Tools

**Production:**
- Target device: iPhone/iPad running iOS 18.2 or later
- Minimum supported deployment: iOS 18.2
- 64-bit architecture (arm64)

## Asset Management

**Asset Catalog:**
- Located in `TOY/Assets.xcassets`
- Contains app icon set (`AppIcon.appiconset`)
- Contains accent color asset (`AccentColor.colorset`)
- Preview assets in `TOY/Preview Content/Preview Assets.xcassets`

---

*Stack analysis: 2026-02-01*
