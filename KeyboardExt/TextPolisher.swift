import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Rewrites text with the on-device Apple Intelligence model. Nothing leaves the phone.
enum TextPolisher {
    struct Unavailable: LocalizedError {
        let errorDescription: String?
    }

    enum Style: CaseIterable {
        case polish, shorter, formal, friendly

        var title: String {
            switch self {
            case .polish: return "Polish"
            case .shorter: return "Make shorter"
            case .formal: return "More formal"
            case .friendly: return "Friendlier"
            }
        }

        var symbol: String {
            switch self {
            case .polish: return "sparkles"
            case .shorter: return "arrow.down.right.and.arrow.up.left"
            case .formal: return "briefcase"
            case .friendly: return "face.smiling"
            }
        }

        fileprivate var direction: String {
            switch self {
            case .polish: return "Keep the tone as it is."
            case .shorter: return "Make it noticeably shorter while keeping every point that matters."
            case .formal: return "Make the tone more formal and professional."
            case .friendly: return "Make the tone warmer and friendlier."
            }
        }
    }

    static func polish(_ text: String, style: Style = .polish) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw Unavailable(errorDescription: "Turn on Apple Intelligence to polish text")
            }
            let session = LanguageModelSession(instructions: """
                You are a copy editor inside a keyboard. Rewrite the user's text so it reads clearly, \
                with correct spelling, grammar and punctuation. Keep the meaning and the language it is \
                written in. \(style.direction) Reply with the rewritten text only, with no quotes and no commentary.
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
