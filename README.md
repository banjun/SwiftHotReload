# SwiftHotReload
[![CI](https://github.com/banjun/SwiftHotReload/actions/workflows/main.yml/badge.svg)](https://github.com/banjun/SwiftHotReload/actions/workflows/main.yml)

Hot reload on Swift app using `@_dynamicReplacement`

## 🚧 Concept Implementation

SwiftHotReload is an experimental project. We investigate a real world application of the `@_dynamicReplacement` feature of Swift 5.1+. Many portions are subject to change, including the library name (it's simple & naive name. we don't plan to publish to `CocoaPods/Specs` before resolving them.)

## Supported Platforms

* Xcode 15.x
* Host macOS 13.x, 14.x
* Runtime macOS app
* Runtime simulators for iOS, iPadOS, and possibly visionOS

## Features

* Monitor a swift file for trigger a build (standalone, run on the app runtime process)
* Build a swift file and emit dylib (standalone, run on the app runtime process)
    * Estimate build environmentd and intermediate interfaces
* Load a dylib while the app on runtime
* Supports apps on macOS and simulators for iOS, iPadOS, and possibly visionOS
   * SPM project structures
   * CocoaPods project structures
* Update trigger for SwiftUI views

### TODOs (not yet implemented, nice to have)

* Helper app on host
* Reload on devices
* Less invasive: be easy to adopt & compatible for App Store submission
    * Build settings (-Xfrontend ...)
    * Sandbox restrictions for macOS app
* Load history
* In-place editing

## How to use the Example app

* Open `SwiftHotReload.xcworkspace`
* Modify `targetSwiftFile:` file path to along with your path in `App.swift`
* Run `SwiftHotReloadExample` on Mac or any simulators
* Edit `ReplaceView.swift` and save

## Install

SPM

```
https://github.com/banjun/SwiftHotReload.git
```

CocoaPods

```
pod 'SwiftHotReload', :git => "https://github.com/banjun/SwiftHotReload.git", :branch => "main"
```

or manual copy

## App Implementations & Settings

Set up app as described below and build & run on a supported platform.

### Set a target swift file to be monitored:

```swift
extension App {
    static let reloader = StandaloneReloader(
        // file path to be monitored
        monitoredSwiftFile: Env.shared.estimatedHomeDir!
            .appendingPathComponent("path_to_project/RuntimeOverrides.swift")
    )
    :        
    _ = App.reloader // use to load the lazy static property above and start a file monitor
}
```

### Disable sandbox (only required for macOS app target):

Modify the app entitlements file:

```
App Sandbox = NO
```

### (Optionally but recommended) set build settings:

* Add to `OTHER_SWIFT_FLAGS` of the app target
    * `-Xfrontend` `-enable-implicit-dynamic`
        * use the flag instead of explicitly marking `dynamic` before `func`s or `var`s
    * `-Xfrontend` `-enable-private-imports`
        * use the flag instead of making related  `func`s or `var`s visible by removing `private`

### Create `path_to_project/RuntimeOverrides.swift`:

Any funcs/vars can be replaced (not only for SwiftUI). 

```swift
import AppModuleName

extension ContentView { // <- typically use extension for a type containing func/var to be replaced
    @_dynamicReplacement(for: body) // <- func/var name to be replaced
    var body2: some View { // <- use different name than the original
    :
    }
} 
```

### (Optionally) to update SwiftUI view after reloadings:

```swift
@ObservedObject private var reloader = App.reloader
```


