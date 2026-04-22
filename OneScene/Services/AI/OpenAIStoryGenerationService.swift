//
//  OpenAIStoryGenerationService.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import UIKit

enum OpenAIStoryGenerationError: LocalizedError {
    case missingAPIKey
    case invalidImageData
    case authenticationFailed(String)
    case requestFailed(String)
    case invalidResponse
    case refusal(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが未設定です"
        case .invalidImageData:
            return "画像データの準備に失敗しました"
        case .authenticationFailed(let message):
            return message.isEmpty ? "OpenAI 認証に失敗しました" : message
        case .requestFailed(let message):
            return message.isEmpty ? "OpenAI へのリクエストに失敗しました" : message
        case .invalidResponse:
            return "OpenAI から受け取った結果を解釈できませんでした"
        case .refusal(let message):
            return message.isEmpty ? "OpenAI が生成を完了できませんでした" : message
        }
    }
}

struct OpenAIStoryGenerationService {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateStory(from image: UIImage, configuration: OpenAIConfiguration) async throws -> GeneratedStory {
        let imageURL = try makeImageDataURL(from: image)
        let payload = ResponsesRequest.make(for: configuration.modelID, imageDataURL: imageURL)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIStoryGenerationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorEnvelope = try? decoder.decode(OpenAIErrorEnvelope.self, from: data)
            let message = errorEnvelope?.error.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw OpenAIStoryGenerationError.authenticationFailed(message)
            }

            throw OpenAIStoryGenerationError.requestFailed(message)
        }

        let parsed = try decoder.decode(OpenAIResponseEnvelope.self, from: data)

        if let message = parsed.error?.message, !message.isEmpty {
            throw OpenAIStoryGenerationError.requestFailed(message)
        }

        var refusalMessage: String?
        let collectedText = parsed.output?
            .compactMap { $0.content }
            .flatMap { $0 }
            .compactMap { item -> String? in
                if item.type == "refusal" {
                    refusalMessage = item.refusal
                    return nil
                }

                return item.type == "output_text" ? item.text : nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let refusalMessage, !refusalMessage.isEmpty {
            throw OpenAIStoryGenerationError.refusal(refusalMessage)
        }

        guard let collectedText, !collectedText.isEmpty,
              let jsonData = collectedText.data(using: .utf8) else {
            throw OpenAIStoryGenerationError.invalidResponse
        }

        return try decoder.decode(GeneratedStory.self, from: jsonData)
    }

    private func makeImageDataURL(from image: UIImage) throws -> String {
        let resizedImage = image.resizedForVision(maxLongEdge: 1536)

        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.82) else {
            throw OpenAIStoryGenerationError.invalidImageData
        }

        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }
}

private struct ResponsesRequest: Encodable {
    let model: String
    let input: [InputMessage]
    let maxOutputTokens: Int
    let text: TextConfiguration

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case maxOutputTokens = "max_output_tokens"
        case text
    }

    static func make(for model: String, imageDataURL: String) -> ResponsesRequest {
        ResponsesRequest(
            model: model,
            input: [
                InputMessage(
                    role: "developer",
                    content: [
                        .text(
                            """
                            You are the creative director for a Japanese iPhone app called OneScene.
                            Analyze the user's photo and create a Japanese movie-poster concept.
                            Return only valid JSON that matches the provided schema exactly.
                            The title must feel original and cinematic, written in Japanese.
                            The tagline must be a single Japanese sentence that is evocative but readable.
                            The genre must be exactly one item from the allowed list.
                            Do not mention AI, apps, cameras, JSON, schemas, or safety policies.
                            """
                        )
                    ]
                ),
                InputMessage(
                    role: "user",
                    content: [
                        .text(
                            """
                            この写真を見て、映画ポスター用のタイトル、キャッチコピー、ジャンルを生成してください。
                            ジャンル候補は次の8つのみです。
                            青春、恋愛、サスペンス、SF、ホラー、ヒューマンドラマ、ロードムービー、ファンタジー
                            タイトルは短すぎず、ありきたりすぎない日本語にしてください。
                            キャッチコピーは1文で、日常の一瞬が映画になる感じを大切にしてください。
                            """
                        ),
                        .image(imageDataURL: imageDataURL, detail: "low")
                    ]
                )
            ],
            maxOutputTokens: 220,
            text: TextConfiguration(
                format: .jsonSchema(
                    JSONSchemaFormat(
                        name: "movie_poster_story",
                        strict: true,
                        schema: StorySchema.make()
                    )
                )
            )
        )
    }
}

private struct InputMessage: Encodable {
    let role: String
    let content: [InputContent]
}

private enum InputContent: Encodable {
    case text(String)
    case image(imageDataURL: String, detail: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
        case detail
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let imageDataURL, let detail):
            try container.encode("input_image", forKey: .type)
            try container.encode(imageDataURL, forKey: .imageURL)
            try container.encode(detail, forKey: .detail)
        }
    }
}

private struct TextConfiguration: Encodable {
    let format: ResponseFormat
}

private enum ResponseFormat: Encodable {
    case jsonSchema(JSONSchemaFormat)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .jsonSchema(let format):
            try format.encode(to: encoder)
        }
    }
}

private struct JSONSchemaFormat: Encodable {
    let type = "json_schema"
    let name: String
    let strict: Bool
    let schema: StorySchema
}

private struct StorySchema: Encodable {
    let type = "object"
    let additionalProperties = false
    let properties: StoryProperties
    let required = ["title", "tagline", "genre"]

    static func make() -> StorySchema {
        StorySchema(
            properties: StoryProperties(
                title: .string(description: "A cinematic Japanese movie title."),
                tagline: .string(description: "A single-sentence Japanese tagline."),
                genre: .enum(
                    values: MovieGenre.allCases.map(\.rawValue),
                    description: "One selected genre label from the allowed list."
                )
            )
        )
    }
}

private struct StoryProperties: Encodable {
    let title: SchemaProperty
    let tagline: SchemaProperty
    let genre: SchemaProperty
}

private struct SchemaProperty: Encodable {
    let type: String
    let description: String
    let values: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case values = "enum"
    }

    static func string(description: String) -> SchemaProperty {
        SchemaProperty(type: "string", description: description, values: nil)
    }

    static func `enum`(values: [String], description: String) -> SchemaProperty {
        SchemaProperty(type: "string", description: description, values: values)
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: OpenAIErrorPayload
}

private struct OpenAIErrorPayload: Decodable {
    let message: String
}

private struct OpenAIResponseEnvelope: Decodable {
    let error: OpenAIResponseError?
    let output: [OpenAIOutputItem]?
}

private struct OpenAIResponseError: Decodable {
    let message: String?
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIOutputContent]?
}

private struct OpenAIOutputContent: Decodable {
    let type: String
    let text: String?
    let refusal: String?
}

private extension UIImage {
    func resizedForVision(maxLongEdge: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)

        guard longestSide > maxLongEdge else {
            return self
        }

        let scale = maxLongEdge / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
