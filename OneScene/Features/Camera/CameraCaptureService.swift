@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UIKit

final class CameraCaptureService: NSObject {
    let session = AVCaptureSession()

    var onAuthorizationChanged: ((AVAuthorizationStatus) -> Void)?
    var onImageCaptured: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    var onPositionChanged: ((CameraLens) -> Void)?
    var onZoomStateChanged: ((CGFloat, ClosedRange<CGFloat>) -> Void)?

    private let sessionQueue = DispatchQueue(label: "app.onescene.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var isConfigured = false
    private let maximumUserZoomFactor: CGFloat = 5
    private let minimumBackCameraDisplayZoomFactor: CGFloat = 0.5
    private let minimumFrontCameraDisplayZoomFactor: CGFloat = 1
    private var lastKnownVideoOrientation: AVCaptureVideoOrientation = .portrait
    private var orientationObserver: NSObjectProtocol?
    private(set) var currentLens: CameraLens = .back
    private(set) var currentZoomFactor: CGFloat = 1
    private(set) var zoomRange: ClosedRange<CGFloat> = 1...1

    override init() {
        super.init()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateLastKnownVideoOrientation()
        }
    }

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
    }

    func prepare() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        updateLastKnownVideoOrientation()

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.onAuthorizationChanged?(status)
        }

        switch status {
        case .authorized:
            configureIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                let updatedStatus: AVAuthorizationStatus = granted ? .authorized : .denied
                DispatchQueue.main.async {
                    self.onAuthorizationChanged?(updatedStatus)
                }

                if granted {
                    self.configureIfNeeded()
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func startRunning() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func switchCamera() {
        let nextLens: CameraLens = currentLens == .back ? .front : .back
        currentZoomFactor = 1
        configureSession(for: nextLens)
    }

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.currentInput?.device else { return }
            self.applyZoomFactor(factor, to: device)
        }
    }

    func capturePhoto() {
        sessionQueue.async {
            guard self.isConfigured else {
                self.emitError("カメラの準備ができていません")
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality

            if let photoConnection = self.photoOutput.connection(with: .video),
               photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = self.lastKnownVideoOrientation
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }

                defer {
                    self.captureDelegates[Int64(settings.uniqueID)] = nil
                }

                switch result {
                case .success(let image):
                    self.stopRunning()
                    DispatchQueue.main.async {
                        self.onImageCaptured?(image)
                    }
                case .failure:
                    self.emitError("撮影に失敗しました")
                }
            }

            self.captureDelegates[Int64(settings.uniqueID)] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else {
            startRunning()
            return
        }

        configureSession(for: .back)
    }

    private func configureSession(for lens: CameraLens) {
        sessionQueue.async {
            guard let device = self.preferredCaptureDevice(for: lens) else {
                self.emitError("利用できるカメラが見つかりません")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                if let currentInput = self.currentInput {
                    self.session.removeInput(currentInput)
                }

                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.emitError("カメラ入力を追加できません")
                    return
                }

                self.session.addInput(input)
                self.currentInput = input

                if !self.session.outputs.contains(where: { $0 === self.photoOutput }) {
                    guard self.session.canAddOutput(self.photoOutput) else {
                        self.session.commitConfiguration()
                        self.emitError("写真出力を追加できません")
                        return
                    }

                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                }

                self.session.commitConfiguration()

                self.isConfigured = true
                self.currentLens = lens
                self.applyZoomFactor(self.currentZoomFactor, to: device)

                DispatchQueue.main.async {
                    self.onPositionChanged?(lens)
                }

                self.startRunning()
            } catch {
                self.emitError("カメラの初期化に失敗しました")
            }
        }
    }

    private func emitError(_ message: String) {
        DispatchQueue.main.async {
            self.onError?(message)
        }
    }

    private func applyZoomFactor(_ factor: CGFloat, to device: AVCaptureDevice) {
        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.0001)
        let requestedMinimumDisplayZoom = device.position == .back
            ? minimumBackCameraDisplayZoomFactor
            : minimumFrontCameraDisplayZoomFactor

        let minimumDisplayZoom = max(device.minAvailableVideoZoomFactor * multiplier, requestedMinimumDisplayZoom)
        let maximumDisplayZoom = max(
            min(device.maxAvailableVideoZoomFactor * multiplier, maximumUserZoomFactor),
            minimumDisplayZoom
        )
        let clampedDisplayZoom = min(max(factor, minimumDisplayZoom), maximumDisplayZoom)
        let clampedDeviceZoom = clampedDisplayZoom / multiplier

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedDeviceZoom
            device.unlockForConfiguration()

            currentZoomFactor = clampedDisplayZoom
            zoomRange = minimumDisplayZoom...maximumDisplayZoom

            DispatchQueue.main.async {
                self.onZoomStateChanged?(clampedDisplayZoom, minimumDisplayZoom...maximumDisplayZoom)
            }
        } catch {
            emitError("ズームの調整に失敗しました")
        }
    }

    private func preferredCaptureDevice(for lens: CameraLens) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        switch lens {
        case .back:
            deviceTypes = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera
            ]
        case .front:
            deviceTypes = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera
            ]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: lens.devicePosition
        )

        for deviceType in deviceTypes {
            if let device = discoverySession.devices.first(where: { $0.deviceType == deviceType }) {
                return device
            }
        }

        return discoverySession.devices.first
    }

    private func updateLastKnownVideoOrientation() {
        guard let resolvedOrientation = Self.resolveVideoOrientation(from: UIDevice.current.orientation) else {
            return
        }

        lastKnownVideoOrientation = resolvedOrientation
    }

    private static func resolveVideoOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    nonisolated(unsafe) private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(.failure(CocoaError(.fileReadCorruptFile)))
            return
        }

        completion(.success(image.normalizedOrientationImage()))
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        if let connection = view.previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session

        if let connection = uiView.previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
