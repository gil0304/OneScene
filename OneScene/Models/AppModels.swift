import AVFoundation
import SwiftUI

enum AppScreen: Equatable {
    case home
    case camera
    case review
    case generating
    case result
}

enum CameraLens: String, Codable {
    case back
    case front

    var label: String {
        switch self {
        case .back:
            return "外カメラ"
        case .front:
            return "内カメラ"
        }
    }

    var devicePosition: AVCaptureDevice.Position {
        switch self {
        case .back:
            return .back
        case .front:
            return .front
        }
    }

    init(position: AVCaptureDevice.Position) {
        switch position {
        case .front:
            self = .front
        default:
            self = .back
        }
    }
}

enum MovieGenre: String, CaseIterable, Codable, Identifiable {
    case youth = "青春"
    case romance = "恋愛"
    case suspense = "サスペンス"
    case scienceFiction = "SF"
    case horror = "ホラー"
    case humanDrama = "ヒューマンドラマ"
    case roadMovie = "ロードムービー"
    case fantasy = "ファンタジー"

    var id: String { rawValue }

    var badgeGradient: LinearGradient {
        switch self {
        case .youth:
            return LinearGradient(colors: [Color(hex: "9B85FF"), Color(hex: "FF8DD8")], startPoint: .leading, endPoint: .trailing)
        case .romance:
            return LinearGradient(colors: [Color(hex: "FF8BA3"), Color(hex: "FFC38A")], startPoint: .leading, endPoint: .trailing)
        case .suspense:
            return LinearGradient(colors: [Color(hex: "98A2B8"), Color(hex: "475467")], startPoint: .leading, endPoint: .trailing)
        case .scienceFiction:
            return LinearGradient(colors: [Color(hex: "27D3D1"), Color(hex: "2B7FFF")], startPoint: .leading, endPoint: .trailing)
        case .horror:
            return LinearGradient(colors: [Color(hex: "B42318"), Color(hex: "027A48")], startPoint: .leading, endPoint: .trailing)
        case .humanDrama:
            return LinearGradient(colors: [Color(hex: "D0A76D"), Color(hex: "8E6A52")], startPoint: .leading, endPoint: .trailing)
        case .roadMovie:
            return LinearGradient(colors: [Color(hex: "FDB022"), Color(hex: "F38744")], startPoint: .leading, endPoint: .trailing)
        case .fantasy:
            return LinearGradient(colors: [Color(hex: "8E7BFF"), Color(hex: "61B7FF")], startPoint: .leading, endPoint: .trailing)
        }
    }
}

struct GeneratedStory: Codable {
    let title: String
    let tagline: String
    let genre: MovieGenre
}

struct PosterRecord: Codable {
    let story: GeneratedStory
    let createdAt: Date
    let posterFilename: String
    let sourceAspectRatio: Double
    let lens: CameraLens

    var formattedCreatedAt: String {
        Self.dateFormatter.string(from: createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
