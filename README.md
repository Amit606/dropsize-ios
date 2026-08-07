# Dropsize — Photo & Video Compressor

Dropsize is a premium, privacy-first iOS utility application designed to compress photos and videos to an exact target file size with minimal visual quality loss. 

Built natively in Swift and SwiftUI, the application performs 100% on-device processing and integrates seamlessly with standard iOS system features.

---

## Key Features

1. **Exact-Target Size Compressor:** Select a photo or video and specify an exact file size target (e.g. 1.0 MB, 2.0 MB). The engine dynamically searches for the optimal quality factor and resolution scale.
2. **Batch Compression:** Select and queue up to 15 images/videos to compress in parallel with individual progress indicators.
3. **Share Sheet Extension:** Compress files directly from native system apps (like Photos, Files, or Safari) without opening the main application.
4. **Home Screen Widget:** Displays the last compressed image thumbnail with deep-link hooks back to the app (supports Small and Medium layouts).
5. **Storage Savings History:** A local history dashboard that logs previous compressions, details, and tracks aggregate storage space saved.
6. **StoreKit 2 Integration:** Auto-renewable subscriptions (weekly/yearly options) simulating Apple's native transaction workflows.
7. **EXIF/GPS Metadata Stripping:** Toggable preference to strip camera details and location markers for enhanced privacy and file reduction.
8. **Dynamic System Themes:** Modern glassmorphic dark theme with full support for Light/Dark appearance states.

---

## Technical Architecture

* **Language:** Swift 5.9+
* **Framework:** SwiftUI
* **Image Compression:** Custom quality binary-search (`[0.0, 1.0]`) combined with pixel scale-down fallbacks using Core Image/UIKit.
* **Video Compression:** Raw video buffer transcoding using `AVAssetReader` and `AVAssetWriter` for custom target bitrates.
* **Storage Sandbox:** Shared App Groups (`group.com.kwh.dropsize`) enabling container access between the main app, share sheet extension, and widget target.
* **Project Generation:** Project files are declared declaratively via `project.yml` and managed using **XcodeGen**.

---

## How to Build and Run

This project uses **XcodeGen** to manage project settings. The `.xcodeproj` file is git-ignored and should be generated locally.

### Prerequisites
Install XcodeGen via Homebrew:
```bash
brew install xcodegen
```

### Steps to Run
1. Clone the repository:
   ```bash
   git clone https://github.com/Amit606/dropsize-ios.git
   cd dropsize-ios
   ```
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open the generated project:
   ```bash
   open Dropsize.xcodeproj
   ```
4. Select your simulator/device target in Xcode and press **Run (Cmd + R)**.
