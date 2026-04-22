import Foundation
import Photos
import UIKit

struct PersistedWork {
    let record: PosterRecord
    let posterImage: UIImage?
}

final class PosterPersistenceStore {
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

enum PhotoLibrarySaver {
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
