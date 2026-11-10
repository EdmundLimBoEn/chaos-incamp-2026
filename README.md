# sstincky calander

Offline SwiftUI calendar prototype. Open `sstincky calander.xcodeproj` in Xcode, choose a signing team and an iPhone, then Run.

Year, month and day views; search; create, edit and delete events. Sample events appear on first launch. Data stays in Application Support as atomic JSON.

Minimum: iOS 26.3. AlarmKit alarms require iOS 26 or later. Generated with XcodeGen (`xcodegen generate`). Built with Xcode 27.1 and installed on the test iPhone.

Convex sync is not connected. Stable event IDs, update timestamps and deletion tombstones are included for a later sync adapter. Local event reminders and AlarmKit alarms are included. Overlapping timed events appear side by side with red conflict borders. Recurrence is not implemented. Notification and alarm permission are requested when needed. The nearest 60 event reminders are scheduled; opening the app refreshes the queue.

Written by gpt-6.1-sol in Codex on behalf of Edmund

Home Screen widget: small and medium upcoming-event views. Both targets use `group.systems.edmundlim.daymark`; enable that App Group for your signing team, run the app once, then add the widget from the Home Screen.

Search understands dates, times, @people and #tags, with filters and prefilled event creation. The sliders menu contains themes, secondary calendar dates and public Convex discovery. Public discovery is connected to the development Convex deployment. Username/password sign-in supports public publishing. Private cloud sync is still pending.

Tap Create event for an offline private event. Use sliders → Create public event to sign up or sign in, enter a host profile and publish; password recovery is not implemented.
