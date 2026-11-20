import UIKit

/// Word suggestions and spelling fixes from the system dictionary (`UITextChecker`).
/// This completes and corrects the word being typed; it does not predict the next word.
final class SuggestionEngine {
    /// Used only from the suggestion queue.
    private let checker = UITextChecker()
    /// Used only from the main thread, so the two never share a checker.
    private let proofChecker = UITextChecker()

    /// The run of letters right before the cursor, if any.
    static func partialWord(in context: String) -> String {
        var letters: [Character] = []
        for character in context.reversed() {
            guard character.isLetter || character == "'" || character == "’" else { break }
            letters.append(character)
        }
        return String(letters.reversed())
    }

    static func isSentenceStart(_ context: String) -> Bool {
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return true }
        return ".?!\n".contains(last)
    }

    func suggestions(for context: String, locale: String) -> [String] {
        let partial = Self.partialWord(in: context)
        guard !partial.isEmpty else { return starters(locale: locale, sentenceStart: Self.isSentenceStart(context)) }

        let language = Self.language(for: locale)
        let range = NSRange(location: 0, length: (partial as NSString).length)
        var candidates: [String] = []
        let misspelled = checker.rangeOfMisspelledWord(
            in: partial, range: range, startingAt: 0, wrap: false, language: language
        ).location != NSNotFound
        if misspelled {
            candidates += checker.guesses(forWordRange: range, in: partial, language: language) ?? []
        }
        candidates += checker.completions(forPartialWordRange: range, in: partial, language: language) ?? []

        let capitalised = partial.first?.isUppercase == true
        var result = ["“\(partial)”"]
        var seen: Set<String> = [partial.lowercased()]
        for candidate in candidates {
            guard seen.insert(candidate.lowercased()).inserted else { continue }
            result.append(capitalised ? candidate.prefix(1).uppercased() + candidate.dropFirst() : candidate)
            if result.count == 3 { break }
        }
        return result
    }

    /// Replaces misspelled words with the dictionary's first guess and tidies
    /// spacing and sentence capitals. Returns the new text and how many fixes it made.
    func proofread(_ text: String, locale: String) -> (text: String, fixes: Int) {
        let language = Self.language(for: locale)
        var working = text as NSString
        var fixes = 0
        var offset = 0
        while offset < working.length {
            let range = NSRange(location: 0, length: working.length)
            let bad = proofChecker.rangeOfMisspelledWord(
                in: working as String, range: range, startingAt: offset, wrap: false, language: language
            )
            guard bad.location != NSNotFound else { break }
            if let guess = proofChecker.guesses(forWordRange: bad, in: working as String, language: language)?.first {
                working = working.replacingCharacters(in: bad, with: guess) as NSString
                fixes += 1
                offset = bad.location + (guess as NSString).length
            } else {
                offset = bad.location + bad.length
            }
        }

        var result = working as String
        let tidy: [(pattern: String, template: String)] = [
            ("[ \\t]{2,}", " "),
            (" +([,.;:!?])", "$1"),
            ("([,;:!?])(?=[^\\s\\d,.;:!?\"')\\]])", "$1 ")
        ]
        for rule in tidy {
            let before = result
            result = result.replacingOccurrences(of: rule.pattern, with: rule.template, options: .regularExpression)
            if result != before { fixes += 1 }
        }
        if language.hasPrefix("en") {
            let before = result
            result = result.replacingOccurrences(of: "\\bi\\b", with: "I", options: .regularExpression)
            if result != before { fixes += 1 }
        }

        // Capital letter at the start and after sentence punctuation.
        var characters = Array(result)
        var capitaliseNext = true
        var changedCapitals = false
        for index in characters.indices {
            let character = characters[index]
            if capitaliseNext, character.isLetter {
                if character.isLowercase {
                    characters[index] = Character(String(character).uppercased(with: Locale(identifier: locale)))
                    changedCapitals = true
                }
                capitaliseNext = false
            } else if ".?!\n".contains(character) {
                // Only when followed by a space or the end, so "3.5" and "e.g." survive.
                let next = index + 1 < characters.count ? characters[index + 1] : " "
                if next.isWhitespace { capitaliseNext = true }
            } else if !character.isWhitespace {
                capitaliseNext = false
            }
        }
        if changedCapitals {
            result = String(characters)
            fixes += 1
        }
        return (result, fixes)
    }

    private func starters(locale: String, sentenceStart: Bool) -> [String] {
        switch locale.prefix(2) {
        case "de": return sentenceStart ? ["Das", "Ich", "Und"] : ["und", "die", "der"]
        case "tr": return sentenceStart ? ["Bu", "Ben", "Ve"] : ["ve", "bir", "bu"]
        default: return sentenceStart ? ["The", "I", "And"] : ["the", "to", "and"]
        }
    }

    private static func language(for locale: String) -> String {
        let available = UITextChecker.availableLanguages
        if available.contains(locale) { return locale }
        let prefix = String(locale.prefix(2))
        return available.first { $0.hasPrefix(prefix) } ?? "en_US"
    }
}
