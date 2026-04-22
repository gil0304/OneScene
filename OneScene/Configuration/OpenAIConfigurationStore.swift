import Foundation

struct OpenAIConfiguration {
    static let defaultModelID = "gpt-5.4"
    static let secretsFilename = "OpenAISecrets.plist"

    let apiKey: String
    let modelID: String
}

final class OpenAIConfigurationStore {
    private let bundle: Bundle
    private let decoder = PropertyListDecoder()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var savedModelID: String {
        loadSecretsFile()?.modelID ?? OpenAIConfiguration.defaultModelID
    }

    var hasSavedAPIKey: Bool {
        guard let secrets = loadSecretsFile() else { return false }
        return secrets.apiKey != nil
    }

    func loadConfiguration() throws -> OpenAIConfiguration {
        guard let secrets = loadSecretsFile(),
              let apiKey = secrets.apiKey else {
            throw OpenAIStoryGenerationError.missingAPIKey
        }

        return OpenAIConfiguration(
            apiKey: apiKey,
            modelID: secrets.modelID ?? OpenAIConfiguration.defaultModelID
        )
    }

    private func loadSecretsFile() -> OpenAISecretsFile? {
        guard let url = bundle.url(forResource: "OpenAISecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let secrets = try? decoder.decode(OpenAISecretsFile.self, from: data) else {
            return nil
        }

        return secrets.normalized
    }
}

private struct OpenAISecretsFile: Decodable {
    let apiKey: String?
    let modelID: String?

    enum CodingKeys: String, CodingKey {
        case apiKey = "OPENAI_API_KEY"
        case modelID = "OPENAI_MODEL_ID"
    }

    var normalized: OpenAISecretsFile {
        OpenAISecretsFile(
            apiKey: apiKey?.normalizedSecretValue,
            modelID: modelID?.normalizedModelValue
        )
    }
}

private extension String {
    var normalizedSecretValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()

        guard !trimmed.isEmpty,
              !lowercase.contains("put_your_openai_api_key_here"),
              !lowercase.contains("your_openai_api_key"),
              !lowercase.contains("set_me"),
              !lowercase.contains("example") else {
            return nil
        }

        return trimmed
    }

    var normalizedModelValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
