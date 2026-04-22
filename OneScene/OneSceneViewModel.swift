//
//  OneSceneViewModel.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Photos
import SwiftUI
import UIKit

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
            return LinearGradient(colors: [Color(hex: "7CB7FF"), Color(hex: "C8E4FF")], startPoint: .leading, endPoint: .trailing)
        case .romance:
            return LinearGradient(colors: [Color(hex: "FF8BA3"), Color(hex: "FFCC8A")], startPoint: .leading, endPoint: .trailing)
        case .suspense:
            return LinearGradient(colors: [Color(hex: "5D6778"), Color(hex: "222834")], startPoint: .leading, endPoint: .trailing)
        case .scienceFiction:
            return LinearGradient(colors: [Color(hex: "27D3D1"), Color(hex: "2B7FFF")], startPoint: .leading, endPoint: .trailing)
        case .horror:
            return LinearGradient(colors: [Color(hex: "6B0303"), Color(hex: "164F33")], startPoint: .leading, endPoint: .trailing)
        case .humanDrama:
            return LinearGradient(colors: [Color(hex: "CB9E65"), Color(hex: "8A6B52")], startPoint: .leading, endPoint: .trailing)
        case .roadMovie:
            return LinearGradient(colors: [Color(hex: "FFB54A"), Color(hex: "E37A52")], startPoint: .leading, endPoint: .trailing)
        case .fantasy:
            return LinearGradient(colors: [Color(hex: "8E7BFF"), Color(hex: "4DAEFF")], startPoint: .leading, endPoint: .trailing)
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

@MainActor
final class OneSceneViewModel: ObservableObject {
    @Published var screen: AppScreen = .home
    @Published var latestRecord: PosterRecord?
    @Published var latestPoster: UIImage?
    @Published var previewImage: UIImage?
    @Published var generationMessage = "タイトルを考えています"
    @Published var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var cameraLens: CameraLens = .back
    @Published var toastMessage: String?
    @Published var isSettingsPresented = false
    @Published private(set) var isOpenAIConfigured = false
    @Published private(set) var openAIModelID = OpenAIConfiguration.defaultModelID

    private let persistenceStore = PosterPersistenceStore()
    private let configurationStore = OpenAIConfigurationStore()
    private let generationService = OpenAIStoryGenerationService()
    private let posterComposer = PosterComposer()
    private let cameraService = CameraCaptureService()
    private var toastTask: Task<Void, Never>?

    init() {
        bindCameraService()
        refreshOpenAIConfigurationState()
        loadPersistedWork()
    }

    var cameraSession: AVCaptureSession {
        cameraService.session
    }

    var hasGeneratedToday: Bool {
        guard let latestRecord else { return false }
        return Calendar.autoupdatingCurrent.isDateInToday(latestRecord.createdAt)
    }

    var canViewLatestWork: Bool {
        latestRecord != nil && latestPoster != nil
    }

    var todayStatusText: String {
        hasGeneratedToday ? "今日は生成済みです" : "今日の1枚をまだ撮っていません"
    }

    var statusDetailText: String {
        if !isOpenAIConfigured {
            return "まず OpenAI APIキーを設定すると、撮影した写真からタイトル・キャッチコピー・ジャンルを実AIで生成できます。"
        }

        if hasGeneratedToday {
            return "再生成は翌日 0:00 以降に可能です。保存やシェアは引き続き行えます。"
        }

        return "アプリ内カメラで撮った1枚を OpenAI へ送り、タイトル・キャッチコピー・ジャンルを生成してポスター化します。"
    }

    var openAIStatusText: String {
        isOpenAIConfigured ? "OpenAI 接続済み" : "APIキー未設定"
    }

    var shareURL: URL? {
        guard let latestRecord else { return nil }
        return try? persistenceStore.posterURL(for: latestRecord.posterFilename)
    }

    func startCaptureFlow() {
        guard isOpenAIConfigured else {
            showToast("OpenAI APIキーを設定してください")
            presentSettings()
            return
        }

        guard !hasGeneratedToday else {
            showToast("今日はすでに生成済みです")
            return
        }

        previewImage = nil
        screen = .camera
        prepareCamera()
    }

    func prepareCamera() {
        cameraService.prepare()
    }

    func stopCamera() {
        cameraService.stopRunning()
    }

    func switchCamera() {
        cameraService.switchCamera()
    }

    func capturePhoto() {
        cameraService.capturePhoto()
    }

    func retakePhoto() {
        previewImage = nil
        screen = .camera
        cameraService.startRunning()
    }

    func confirmCapturedPhoto() {
        guard let previewImage else { return }

        screen = .generating
        cameraService.stopRunning()

        Task {
            await generatePoster(from: previewImage)
        }
    }

    func openLatestResult() {
        guard canViewLatestWork else {
            showToast("まだ作品がありません")
            return
        }

        screen = .result
    }

    func returnHome() {
        stopCamera()
        previewImage = nil
        screen = .home
    }

    func presentSettings() {
        isSettingsPresented = true
    }

    func currentOpenAIAPIKey() -> String {
        configurationStore.loadSavedAPIKey()
    }

    @discardableResult
    func saveOpenAIConfiguration(apiKey: String, modelID: String) -> Bool {
        do {
            try configurationStore.save(apiKey: apiKey, modelID: modelID)
            refreshOpenAIConfigurationState()
            showToast("OpenAI 設定を保存しました")
            return true
        } catch let error as OpenAIStoryGenerationError {
            showToast(error.localizedDescription)
            return false
        } catch {
            showToast("設定の保存に失敗しました")
            return false
        }
    }

    func clearOpenAIConfiguration() {
        do {
            try configurationStore.clear()
            refreshOpenAIConfigurationState()
            showToast("OpenAI 設定を削除しました")
        } catch {
            showToast("設定の削除に失敗しました")
        }
    }

    func saveLatestPosterToLibrary() {
        guard let latestPoster else {
            showToast("保存できるポスターがありません")
            return
        }

        Task {
            do {
                try await PhotoLibrarySaver.save(image: latestPoster)
                showToast("写真アプリに保存しました")
            } catch {
                showToast("保存に失敗しました")
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func bindCameraService() {
        cameraService.onAuthorizationChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.cameraAuthorizationStatus = status
            }
        }

        cameraService.onPositionChanged = { [weak self] lens in
            DispatchQueue.main.async {
                self?.cameraLens = lens
            }
        }

        cameraService.onImageCaptured = { [weak self] image in
            DispatchQueue.main.async {
                self?.previewImage = image
                self?.screen = .review
            }
        }

        cameraService.onError = { [weak self] errorMessage in
            DispatchQueue.main.async {
                self?.showToast(errorMessage)
            }
        }
    }

    private func loadPersistedWork() {
        guard let loaded = persistenceStore.loadLatestRecord() else { return }
        latestRecord = loaded.record
        latestPoster = loaded.posterImage
    }

    private func generatePoster(from image: UIImage) async {
        do {
            generationMessage = "写真をAIへ送信しています"
            try await Task.sleep(nanoseconds: 350_000_000)

            let configuration = try configurationStore.loadConfiguration()

            generationMessage = "タイトルとコピーを生成しています"
            let story = try await generationService.generateStory(from: image, configuration: configuration)

            generationMessage = "映画の雰囲気を整えています"
            let createdAt = Date()
            let posterImage = posterComposer.renderPoster(from: image, story: story, createdAt: createdAt)

            generationMessage = "ポスターを仕上げています"
            try await Task.sleep(nanoseconds: 450_000_000)

            let record = PosterRecord(
                story: story,
                createdAt: createdAt,
                posterFilename: "latest-poster.jpg",
                sourceAspectRatio: image.aspectRatio,
                lens: cameraLens
            )

            try persistenceStore.save(record: record, posterImage: posterImage)

            latestRecord = record
            latestPoster = posterImage
            previewImage = nil
            screen = .result
        } catch is CancellationError {
            showToast("生成を中断しました")
            screen = .home
        } catch let error as OpenAIStoryGenerationError {
            handleGenerationError(error)
        } catch {
            showToast("生成に失敗しました")
            screen = previewImage == nil ? .home : .review
        }
    }

    private func refreshOpenAIConfigurationState() {
        isOpenAIConfigured = configurationStore.hasSavedAPIKey
        openAIModelID = configurationStore.savedModelID
    }

    private func handleGenerationError(_ error: OpenAIStoryGenerationError) {
        switch error {
        case .missingAPIKey:
            showToast("OpenAI APIキーを設定してください")
            presentSettings()
        case .authenticationFailed:
            showToast("OpenAI 認証に失敗しました")
            presentSettings()
        case .requestFailed(let message):
            showToast(message)
        case .invalidImageData, .invalidResponse, .refusal:
            showToast(error.localizedDescription)
        }

        screen = previewImage == nil ? .home : .review
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}

private struct PersistedWork {
    let record: PosterRecord
    let posterImage: UIImage?
}

private final class PosterPersistenceStore {
    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let recordKey = "onescene.latest.record"

    func loadLatestRecord() -> PersistedWork? {
        guard let data = defaults.data(forKey: recordKey),
              let record = try? decoder.decode(PosterRecord.self, from: data) else {
            return nil
        }

        let posterImageURL = try? posterURL(for: record.posterFilename)
        let posterImage = posterImageURL.flatMap { UIImage(contentsOfFile: $0.path) }

        return PersistedWork(record: record, posterImage: posterImage)
    }

    func save(record: PosterRecord, posterImage: UIImage) throws {
        let recordData = try encoder.encode(record)
        let outputURL = try posterURL(for: record.posterFilename)

        guard let jpegData = posterImage.jpegData(compressionQuality: 0.94) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try jpegData.write(to: outputURL, options: .atomic)
        defaults.set(recordData, forKey: recordKey)
    }

    func posterURL(for filename: String) throws -> URL {
        let directoryURL = try postersDirectoryURL()
        return directoryURL.appendingPathComponent(filename)
    }

    private func postersDirectoryURL() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directoryURL = baseURL.appendingPathComponent("OneScenePosters", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }
}

private struct LocalPosterGenerationEngine {
    private let context = CIContext(options: nil)

    func generateStory(from image: UIImage) -> GeneratedStory {
        let insight = analyze(image: image)
        let genre = pickGenre(for: insight)
        let seed = makeSeed(from: insight)

        return GeneratedStory(
            title: makeTitle(for: genre, seed: seed),
            tagline: makeTagline(for: genre, seed: seed),
            genre: genre
        )
    }

    private func analyze(image: UIImage) -> ImageInsight {
        let fallback = ImageInsight(red: 0.44, green: 0.42, blue: 0.48, saturation: 0.28, brightness: 0.44, aspectRatio: image.aspectRatio)

        guard let ciImage = CIImage(image: image) else {
            return fallback
        }

        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent

        guard let outputImage = filter.outputImage else {
            return fallback
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let red = CGFloat(bitmap[0]) / 255
        let green = CGFloat(bitmap[1]) / 255
        let blue = CGFloat(bitmap[2]) / 255

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(red: red, green: green, blue: blue, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return ImageInsight(
            red: red,
            green: green,
            blue: blue,
            saturation: saturation,
            brightness: brightness,
            aspectRatio: image.aspectRatio
        )
    }

    private func pickGenre(for insight: ImageInsight) -> MovieGenre {
        let warmth = insight.red - insight.blue
        let coolness = insight.blue - insight.red

        if insight.brightness < 0.18 {
            return .horror
        }

        if insight.saturation < 0.18 && insight.brightness < 0.42 {
            return .suspense
        }

        if coolness > 0.12 && insight.green > 0.36 && insight.saturation > 0.34 {
            return .scienceFiction
        }

        if warmth > 0.12 && insight.brightness > 0.58 {
            return .romance
        }

        if insight.aspectRatio > 1.25 && insight.brightness > 0.4 {
            return .roadMovie
        }

        if insight.brightness > 0.72 && coolness > 0.02 {
            return .youth
        }

        if insight.saturation > 0.5 && insight.brightness > 0.56 {
            return .fantasy
        }

        if insight.brightness < 0.36 {
            return .suspense
        }

        return .humanDrama
    }

    private func makeTitle(for genre: MovieGenre, seed: Int) -> String {
        let prefixes = [
            "午前7時の", "帰り道の", "まだ名前のない", "静かな", "あの日の", "フィルムの端にある", "誰も知らない", "光を待つ"
        ]

        let nouns: [MovieGenre: [String]] = [
            .youth: ["助走", "横顔", "決意", "季節", "約束"],
            .romance: ["体温", "距離", "余白", "まなざし", "秘密"],
            .suspense: ["沈黙", "兆し", "違和感", "裏側", "影"],
            .scienceFiction: ["信号", "残響", "軌道", "境界線", "明滅"],
            .horror: ["気配", "痕跡", "囁き", "夜気", "深部"],
            .humanDrama: ["台所", "灯り", "手ざわり", "呼吸", "生活"],
            .roadMovie: ["遠回り", "交差点", "車窓", "夕暮れ", "一本道"],
            .fantasy: ["薄明", "魔法", "余光", "気流", "羽音"]
        ]

        let prefix = prefixes[abs(seed) % prefixes.count]
        let genreNouns = nouns[genre, default: nouns[.humanDrama, default: ["物語"]]]
        let noun = genreNouns[abs(seed / 3) % genreNouns.count]

        return prefix + noun
    }

    private func makeTagline(for genre: MovieGenre, seed: Int) -> String {
        let lines: [MovieGenre: [String]] = [
            .youth: [
                "まだ何も始まっていないようで、心だけはもう走り出していた。",
                "見慣れた景色の中で、今日だけの主人公が目を覚ます。",
                "言葉にする前の気持ちが、先に光をまとっていた。 "
            ],
            .romance: [
                "近づいたのは距離ではなく、見えない温度だった。",
                "ありふれた一瞬が、たった一人のために映画になる。",
                "触れなくても伝わるものだけが、静かに残っていく。 "
            ],
            .suspense: [
                "平穏に見えるほど、その奥に物語は潜んでいる。",
                "違和感は小さいほど、あとから大きく響いてくる。",
                "答えに近づくたびに、景色の輪郭だけが揺れていく。 "
            ],
            .scienceFiction: [
                "日常に混ざった一筋の光が、世界の設定を書き換えていく。",
                "この瞬間だけ、現実は少し未来の色をしていた。",
                "見慣れた風景の奥で、別の時間軸がゆっくり起動する。 "
            ],
            .horror: [
                "静かすぎる空気ほど、こちらを先に見つめている。",
                "何も起きていないはずなのに、気配だけが残っていく。",
                "振り返らなければ平和だったと、あとで誰もが思い出す。 "
            ],
            .humanDrama: [
                "特別じゃない今日だからこそ、ちゃんと物語になる。",
                "大きな事件はなくても、心は静かに更新されていく。",
                "暮らしの輪郭に触れたとき、人は少しだけ前を向ける。 "
            ],
            .roadMovie: [
                "まっすぐじゃない道のほうが、ちゃんと今を連れていく。",
                "通り過ぎる景色の数だけ、今日の気持ちは自由になっていく。",
                "遠くへ行くことより、ここを離れる決心が先に始まった。 "
            ],
            .fantasy: [
                "見慣れた世界に、今日だけ少し魔法の粒子が混ざっている。",
                "光のにじみが、現実の境界をやさしくほどいていく。",
                "ほんの一瞬だけ、この場所は別の名前で呼ばれていた。 "
            ]
        ]

        let candidates = lines[genre, default: lines[.humanDrama, default: ["今日の景色が物語になる。"]]]
        return candidates[abs(seed / 5) % candidates.count].trimmingCharacters(in: .whitespaces)
    }

    private func makeSeed(from insight: ImageInsight) -> Int {
        let red = Int((insight.red * 1000).rounded())
        let green = Int((insight.green * 2000).rounded())
        let blue = Int((insight.blue * 3000).rounded())
        let saturation = Int((insight.saturation * 1000).rounded())
        let brightness = Int((insight.brightness * 1000).rounded())
        let ratio = Int((insight.aspectRatio * 100).rounded())

        return red ^ green ^ blue ^ saturation ^ brightness ^ ratio
    }
}

private struct ImageInsight {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let aspectRatio: CGFloat
}

private enum PhotoLibrarySaver {
    static func save(image: UIImage) async throws {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let resolvedStatus: PHAuthorizationStatus

        if currentStatus == .notDetermined {
            resolvedStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            resolvedStatus = currentStatus
        }

        guard resolvedStatus == .authorized || resolvedStatus == .limited else {
            throw CocoaError(.userCancelled)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: CocoaError(.fileWriteUnknown))
                }
            }
        }
    }
}
