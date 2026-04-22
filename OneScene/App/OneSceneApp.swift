import SwiftUI

@main
struct OneSceneApp: App {
    init() {
        BrandFontRegistrar.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
