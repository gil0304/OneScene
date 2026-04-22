//
//  OneSceneViewModel.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class OneSceneViewModel: ObservableObject {
    @Published var screen: AppScreen = .home
    @Published var latestRecord: PosterRecord?
    @Published var latestPoster: UIImage?
    @Published var previewImage: UIImage?
    @Published var generationMessage = "タイトルを考えています"
    @Published var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var cameraLens: CameraLens = .back
    @Published var zoomFactor: CGFloat = 1
    @Published var toastMessage: String?
    @Published private(set) var isOpenAIConfigured = false
    @Published private(set) var maxZoomFactor: CGFloat = 1
    @Published private(set) var openAIModelID = OpenAIConfiguration.defaultModelID

    private let persistenceStore = PosterPersistenceStore()
    private let configurationStore = OpenAIConfigurationStore()
    private let generationService = OpenAIStoryGenerationService()
    private let posterComposer = PosterComposer()
    private let cameraService = CameraCaptureService()
    private var toastTask: Task<Void, Never>?
    private var pinchStartZoomFactor: CGFloat = 1

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
            return "`\(OpenAIConfiguration.secretsFilename)` に APIキーを入れてから撮影を始めます。テンプレートは `OpenAISecrets.example.plist` です。"
        }

        if hasGeneratedToday {
            return "再生成は翌日 0:00 以降に可能です。保存やシェアは引き続き行えます。"
        }

        return "アプリ内カメラで撮った1枚を映画ポスターへ仕上げます。"
    }

    var openAIStatusText: String {
        isOpenAIConfigured ? "OpenAI 接続準備完了" : "APIキー未設定"
    }

    var secretConfigurationHint: String {
        "Configuration/Secrets/\(OpenAIConfiguration.secretsFilename)"
    }

    var shareURL: URL? {
        guard let latestRecord else { return nil }
        return try? persistenceStore.posterURL(for: latestRecord.posterFilename)
    }

    func startCaptureFlow() {
        refreshOpenAIConfigurationState()

        guard isOpenAIConfigured else {
            showToast("\(OpenAIConfiguration.secretsFilename) に APIキーを設定してください")
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

    func setZoomFactor(_ factor: CGFloat) {
        cameraService.setZoomFactor(factor)
    }

    func beginZoomGesture() {
        pinchStartZoomFactor = zoomFactor
    }

    func updateZoomGesture(scale: CGFloat) {
        cameraService.setZoomFactor(pinchStartZoomFactor * scale)
    }

    func endZoomGesture() {
        pinchStartZoomFactor = zoomFactor
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

        cameraService.onZoomStateChanged = { [weak self] factor, range in
            DispatchQueue.main.async {
                self?.zoomFactor = factor
                self?.maxZoomFactor = range.upperBound
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
            generationMessage = "写真を送信しています"
            try await Task.sleep(nanoseconds: 350_000_000)

            let configuration = try configurationStore.loadConfiguration()

            generationMessage = "タイトルとコピーを生成しています"
            let story = try await generationService.generateStory(from: image, configuration: configuration)

            generationMessage = "ポスターのレイアウトを整えています"
            let createdAt = Date()
            let posterImage = posterComposer.renderPoster(from: image, story: story, createdAt: createdAt)

            generationMessage = "映画ポスターを仕上げています"
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
            showToast("\(OpenAIConfiguration.secretsFilename) に APIキーを設定してください")
        case .authenticationFailed:
            showToast("OpenAI 認証に失敗しました。秘密ファイルのキーを確認してください")
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
