# iCore

iPad virtualization engine powered by Hypervisor.framework.

## Overview

iCore is a SwiftUI application that virtualizes ARM64 operating systems on iPad Air M1 using Apple's Hypervisor.framework C API. Version 1 boots a minimal ARM64 test binary and displays serial output.

## Features

- **Dashboard** — VM status indicator, RAM/storage usage bars, start/settings controls
- **Console** — Real-time scrolling serial output from the virtual machine
- **Settings** — Configure RAM (1–6 GB), storage (8–64 GB), CPU cores (1/2/4), network toggle
- **Hypervisor.framework** — Direct C API via dlopen (hv_vm_create, hv_vcpu_run, etc.)
- **Demo mode** — Simulated boot output when Hypervisor.framework is unavailable

## Requirements

- iPad Air M1 (2022) or later with Apple Silicon
- iPadOS 17.0+
- Sideloaded via [Sideloadly](https://sideloadly.io/)

## Build

### Local (macOS)

```bash
brew install xcodegen
xcodegen generate
open iCore.xcodeproj
```

### CI (GitHub Actions)

Push to `main` triggers the workflow automatically. The `.ipa` artifact is available in the Actions tab.

## Architecture

```
iCore/
├── iCoreApp.swift          # App entry point
├── Views/
│   ├── DashboardView.swift # Home screen with status + resource bars
│   ├── ConsoleView.swift   # Serial output display
│   └── SettingsView.swift  # VM configuration
└── VM/
    ├── VMManager.swift         # VM lifecycle manager (ObservableObject)
    ├── HypervisorWrapper.swift # dlopen bridge to Hypervisor.framework
    └── VirtioConsole.swift     # MMIO serial console
```

## License

MIT
