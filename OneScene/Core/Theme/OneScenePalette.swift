//
//  OneScenePalette.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import SwiftUI

enum OneScenePalette {
    static let background = Color(hex: "0F1117")
    static let cardBase = Color(hex: "171A22")
    static let primaryText = Color(hex: "F5F7FB")
    static let secondaryText = Color(hex: "A8B0C0")
    static let accent = Color(hex: "7C5CFF")
    static let secondaryAccent = Color(hex: "4FD1C5")
    static let warning = Color(hex: "FF6B6B")
    static let cardFill = cardBase.opacity(0.92)

    static let backgroundGradient = LinearGradient(
        colors: [
            background,
            Color(hex: "131824"),
            background
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum OneSceneBrandFont {
    static let postScriptName = "ArtemisInterRegular"
}

extension Font {
    static func oneSceneBrand(size: CGFloat) -> Font {
        .custom(OneSceneBrandFont.postScriptName, size: size)
    }
}
