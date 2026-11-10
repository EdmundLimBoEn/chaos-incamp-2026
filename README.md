# Daymark

Offline SwiftUI calendar prototype. Open `Daymark.xcodeproj` in Xcode, choose a signing team and an iPhone, then Run.

Year, month and day views; search; create, edit and delete events. Sample events appear on first launch. Data stays in Application Support as atomic JSON.

Target: iOS 27.3. Generated with XcodeGen (`xcodegen generate`). This machine has Xcode 27.1; no build or simulator run was performed.

Convex sync is not connected. Stable event IDs, update timestamps and deletion tombstones are included for a later sync adapter. Recurrence, notifications and overlapping timeline layout are not implemented.

Written by gpt-6.1-sol in Codex on behalf of Edmund
