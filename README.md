# SwiftHotReload
[![CI](https://github.com/banjun/SwiftHotReload/actions/workflows/main.yml/badge.svg)](https://github.com/banjun/SwiftHotReload/actions/workflows/main.yml)

Hot reload on Swift app using `@_dynamicReplacement`

## 🚧 Concept Implementation

SwiftHotReload is an experimental project. We investigate a real world application of the `@_dynamicReplacement` feature of Swift 5.1+. Many portions are subject to change, including the library name (it's simple & naive name. we don't plan to publish to `CocoaPods/Specs` before resolving them.)

## Supported Platforms

* Xcode 16.x
* Host macOS 14.x, 15.x

We can use either Standalone Reloader or Proxy Reloader. Standalone Reloader runs all required tasks on the runtime target process. Proxy Reloader runs on the runtime target process and receives dylibs from BuildHelper via network. BuildHelper runs on the host Mac and monitors file changes to build the file and send dylibs to Proxy on the target.

| Runtime Target App            | Standalone | Proxy & BuildHelper |    
|-------------------------------|------------|---------------------|
| iOS app on Simulator          | ✅         | ✅ |
| iOS app on Device             | ❌         | ✅ (codesign with Individual, Company or Enterprise ADP) |
| macOS app (App Sandbox = NO)  | ✅         | ✅ |
| macOS app (App Sandbox = YES) | ❌         | ❌ (codesign cannot be trusted to load) |
| macOS app (Designed for iPad) | ❌         | ❌ (codesign cannot be trusted to load) |
| visionOS app on Simulator     | ✅         | ✅ |
| visionOS app on Device        | ❌         | ✅ (codesign with Individual, Company or Enterprise ADP) |


## Features

* Monitor a swift file for trigger a build (standalone, run on the app runtime process)
* Build a swift file and emit dylib (standalone, run on the app runtime process)
    * Estimate build environmentd and intermediate interfaces
* Load a dylib while the app on runtime
* Supports apps on macOS and simulators for iOS, iPadOS, and visionOS
   * SPM project structures
   * CocoaPods project structures
* Update trigger for SwiftUI views
* Helper app on host & Reload on devices
* Compatible for App Store submission, as long as caller side suppress any calls in Release build

### TODOs (not yet implemented, nice to have)

* Less invasive: be easy to adopt & compatible for App Store submission
    * Build settings (-Xfrontend ...)
    * Sandbox restrictions for macOS app
* Load history
* In-place editing

## How to use the Example app

* Open `SwiftHotReload.xcworkspace`
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
    static let reloader = StandaloneReloader(monitoredSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        // file path to be monitored
        .appendingPathComponent("RuntimeOverrides.swift")
    :        
    _ = App.reloader // use to load the lazy static property above and start a file monitor
}
```

### (on iOS Device) Use ProxyReloader & BuildHelper

If the app is for iOS Device, use `ProxyReloader` instead of `StandaloneReloader`. Run BuildHelper separately on the host Mac:

```
git clone https://github.com/banjun/SwiftHotReload.git
cd SwiftHotReload

swift run BuildHelper -c debug
```

Alternatively to `swift run`, we can run BuildHelper as an app (not CLI) using BuildHelper target on SwiftHotReload.xcworkspace.

### (only required for macOS app target) Disable App Sandbox:

Modify the app entitlements file:

```
App Sandbox = NO
```

### (optional but recommended) Set build settings:

* Add to `OTHER_SWIFT_FLAGS` of the app target
    * `-Xfrontend` `-enable-implicit-dynamic`
        * use the flag instead of explicitly marking `dynamic` before `func`s or `var`s
    * `-Xfrontend` `-enable-private-imports`
        * use the flag instead of making related  `func`s or `var`s visible by removing `private`


### (optional) Insert hooks to update SwiftUI view after reloadings:

```swift
@ObservedObject private var reloader = App.reloader
```

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
