import SwiftUI

@main
struct SpeakeasyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.primary)       // one interactive tint (HIG)
                .fontDesign(.rounded)      // SF Rounded — warm, friendly, legible
        }
    }
}
