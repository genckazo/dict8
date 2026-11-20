import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Rewrites text with the on-device Apple Intelligence model. Nothing leaves the phone.
enum TextPolisher {
    struct Unavailable: LocalizedError {
        let errorDescription: String?
    }

    static func polish(_ text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw Unavailable(errorDescription: "Turn on Apple Intelligence to polish text")
            }
            let session = LanguageModelSession(instructions: """
                You are a copy editor inside a keyboard. Rewrite the user's text so it reads clearly, \
                with correct spelling, grammar and punctuation. Keep the meaning, the tone and the language \
                it is written in. Reply with the rewritten text only, with no quotes and no commentary.
                """)
            let response = try await session.respond(to: text)
            let polished = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !polished.isEmpty else { throw Unavailable(errorDescription: "Nothing came back") }
            return polished
        }
        #endif
        throw Unavailable(errorDescription: "Polish needs iOS 26 with Apple Intelligence")
    }
}
