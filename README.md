# Bracketer

Bracketer is a native SwiftUI iPhone camera app for bracketed photography. It captures bracketed exposure sequences, provides a camera-focused shooting UI, and includes an in-app review flow for the latest sequence.

## Requirements

- Xcode 26.2 or newer
- iOS 26.2 simulator or device support

## Project layout

- `Bracketer/`: app source
- `BracketerTests/`: unit tests using Swift Testing
- `BracketerUITests/`: UI tests using XCTest
- `Bracketer.xcodeproj/`: Xcode project

## Local development

Build and test with `xcodebuild`:

```sh
xcodebuild test \
  -project Bracketer.xcodeproj \
  -scheme Bracketer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'
```

Open the project in Xcode:

```sh
open Bracketer.xcodeproj
```

## UI test helpers

The app supports these UI-test launch arguments:

- `-ui-testing-skip-onboarding`: launches directly into the camera screen.
- `-ui-testing-disable-camera-startup`: skips camera and motion startup so UI tests can assert stable chrome without permission or sensor side effects.

## Current priorities

This repository is mid-hardening. The current implementation focus is:

- keeping `main` buildable and testable
- making camera controls truthful
- stabilizing lifecycle and review flows
- adding regression coverage before larger refactors
