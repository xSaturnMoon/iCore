# iCore

> An ARM64 virtualization app for iPad Air M1, powered by `Hypervisor.framework`.

## Overview

iCore boots a minimal ARM64 payload inside a hardware-isolated VM on iPadOS 17+.
Serial output is streamed live to the in-app console.

## Project Structure

```
iCore/
├── project.yml              # XcodeGen spec
├── Info.plist               # iOS bundle metadata
├── iCore.entitlements       # Hypervisor entitlement
├── iCore/
│   ├── iCoreApp.swift       # SwiftUI @main
│   ├── Views/
│   │   ├── DashboardView.swift
│   │   ├── ConsoleView.swift
│   │   └── SettingsView.swift
│   └── VM/
│       ├── VMManager.swift
│       ├── HypervisorWrapper.swift
│       └── VirtioConsole.swift
└── .github/workflows/build.yml
```

## Building Locally

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `iCore.xcodeproj` in Xcode 15.4+
4. Set your signing team and run on an iPad Air M1 (iPadOS 17.0+)

## CI / GitHub Actions

Every push to `main` triggers a build that archives the app and uploads `iCore.ipa`
as a downloadable workflow artifact.

## Sideloading

Download the artifact ZIP from the Actions run, extract `iCore.ipa`, and sideload
via [Sideloadly](https://sideloadly.io/).

## Requirements

- Xcode 15.4+
- iPadOS 17.0+ on Apple Silicon (M1/M2 iPad)
- `com.apple.security.hypervisor` entitlement (included)
