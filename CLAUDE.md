# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS/macOS SwiftUI application named "ethwallet" built with Xcode. It uses SwiftUI for the UI framework and SwiftData for persistence.

## Build and Development Commands

### Building the Project
```bash
# Build for debug
xcodebuild -scheme ethwallet -configuration Debug build

# Build for release
xcodebuild -scheme ethwallet -configuration Release build

# Clean build folder
xcodebuild -scheme ethwallet clean
```

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme ethwallet -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test target
xcodebuild test -scheme ethwallet -only-testing:ethwalletTests
```

### Opening in Xcode
```bash
open ethwallet.xcodeproj
```

## Architecture

The app follows a standard SwiftUI + SwiftData architecture:

- **ethwalletApp.swift**: Main app entry point, sets up the SwiftData ModelContainer
- **ContentView.swift**: Primary view implementing a NavigationSplitView with list/detail pattern
- **Item.swift**: SwiftData model class using @Model macro
- **Test Structure**: Uses Swift Testing framework (not XCTest) with @Test macro

## Key Technical Details

- **Framework**: SwiftUI with SwiftData for persistence
- **Testing**: Swift Testing framework (modern async/await style)
- **Deployment Target**: Check project.pbxproj for specific iOS/macOS versions
- **Data Model**: Simple Item model with timestamp property, stored persistently via SwiftData