import SwiftUI

@main
struct KindlyCallApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.primary)       // one interactive tint (HIG)
                .fontDesign(.rounded)      // SF Rounded — warm, friendly, legible
        }
    }
}
