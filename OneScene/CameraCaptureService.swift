//
//  CameraCaptureService.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

final class CameraCaptureService: NSObject {
    let session = AVCaptureSession()

    var onAuthorizationChanged: ((AVAuthorizationStatus) -> Void)?
    var onImageCaptured: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    var onPositionChanged: ((CameraLens) -> Void)?

    private let sessionQueue = DispatchQueue(label: "app.onescene.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var isConfigured = false
    private(set) var currentLens: CameraLens = .back

    func prepare() {
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
        configureSession(for: nextLens)
    }

    func capturePhoto() {
        sessionQueue.async {
            guard self.isConfigured else {
                self.emitError("カメラの準備ができていません")
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality

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
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: lens.devicePosition) else {
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

        completion(.success(image))
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
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
