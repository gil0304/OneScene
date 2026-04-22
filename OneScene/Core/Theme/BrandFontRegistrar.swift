import CoreText
import Foundation

enum BrandFontRegistrar {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        defer { didRegister = true }

        guard let url = Bundle.main.url(forResource: "Artemis_Inter_041621", withExtension: "otf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
