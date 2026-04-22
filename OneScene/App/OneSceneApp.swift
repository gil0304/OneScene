//
//  OneSceneApp.swift
//  OneScene
//
//  Created by 落合遼梧 on 2026/04/22.
//

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
