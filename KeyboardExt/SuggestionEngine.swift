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

    /// The word before the one being typed, if it is in the same sentence.
    static func previousWord(before partial: String, in context: String) -> String? {
        var rest = Substring(context).dropLast(partial.count)
        while rest.last == " " { rest = rest.dropLast() }
        let word = partialWord(in: String(rest))
        return word.isEmpty ? nil : word
    }

    static func isSentenceStart(_ context: String) -> Bool {
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return true }
        return ".?!\n".contains(last)
    }

    /// Everything worked out about the word being typed.
    struct WordAnalysis {
        let word: String
        let suggestions: [String]
        /// The word autocorrect would type instead, if it is confident enough.
        let correction: String?
        /// True when the dictionary or the person's own vocabulary has the word.
        let known: Bool
    }

    /// Suggestions plus the autocorrect decision for the word at the end of `context`.
    /// Runs on the suggestion queue; `model` and `geometry` are copies.
    func analyse(
        context: String, letters: [TypedLetter], locale: String, geometry: KeyGeometry,
        model: PersonalModelData, autocorrect: Bool, shortcuts: [String: String], names: Set<String>
    ) -> WordAnalysis {
        let partial = Self.partialWord(in: context)
        let previous = Self.previousWord(before: partial, in: context)
        guard !partial.isEmpty else {
            return WordAnalysis(
                word: "", suggestions: nextWords(after: previous, context: context, locale: locale, model: model),
                correction: nil, known: true
            )
        }
        let language = Self.language(for: locale)
        let range = NSRange(location: 0, length: (partial as NSString).length)
        let misspelled = checker.rangeOfMisspelledWord(
            in: partial, range: range, startingAt: 0, wrap: false, language: language
        ).location != NSNotFound
        let lowered = partial.lowercased()
        // A text replacement set up in iOS Settings ("omw" → "On my way!") expands like a correction.
        let expansion = autocorrect ? shortcuts[lowered] : nil
        let known = !misspelled || model.knows(partial) || names.contains(lowered) || expansion != nil
        let guesses = known ? [] : (checker.guesses(forWordRange: range, in: partial, language: language) ?? [])

        var correction: String? = expansion
        if expansion != nil {
            // Nothing else to decide.
        } else if autocorrect, language.hasPrefix("en"), partial == "i", !model.isRejected(partial) {
            correction = "I"
        } else if autocorrect, !known, !model.isRejected(partial), !looksLikeName(partial, in: context) {
            let typed = String(letters.map(\.character)) == partial
                ? letters : partial.map { TypedLetter(character: $0, point: nil) }
            let nearby = neighbourWords(for: Array(lowered), geometry: geometry, model: model, language: language)
            correction = Autocorrector.correction(
                for: typed, candidates: Array(guesses.prefix(8)) + nearby, geometry: geometry, model: model
            )
        }

        let capitalised = partial.first?.isUppercase == true
        var result = ["“\(partial)”"]
        var seen: Set<String> = [lowered]
        var others = model.completions(for: partial, limit: 2)
            + guesses
            + (checker.completions(forPartialWordRange: range, in: partial, language: language) ?? [])
        if let previous {
            // Words this person has typed after the previous one come first; the rest keep their order.
            let ranked = others.enumerated().sorted {
                let a = model.pairCount(previous, $0.element), b = model.pairCount(previous, $1.element)
                return a != b ? a > b : $0.offset < $1.offset
            }
            others = ranked.map(\.element)
        }
        let ordered = [correction].compactMap { $0 } + others
        for candidate in ordered {
            guard seen.insert(candidate.lowercased()).inserted else { continue }
            result.append(capitalised ? candidate.prefix(1).uppercased() + candidate.dropFirst() : candidate)
            if result.count == 3 { break }
        }
        return WordAnalysis(word: partial, suggestions: result, correction: correction, known: known)
    }

    /// What to offer before a word is started: what this person usually types next,
    /// then common followers, then everyday words.
    private func nextWords(after previous: String?, context: String, locale: String, model: PersonalModelData) -> [String] {
        let sentenceStart = Self.isSentenceStart(context)
        var words: [String] = []
        if !sentenceStart, let previous {
            words += model.nextWords(after: previous, limit: 3)
            if locale.hasPrefix("en") { words += Self.commonFollowers[previous.lowercased()] ?? [] }
        }
        words += starters(locale: locale, sentenceStart: sentenceStart)
        var seen = Set<String>()
        var result: [String] = []
        for word in words where seen.insert(word.lowercased()).inserted {
            result.append(word == "i" ? "I" : word)
            if result.count == 3 { break }
        }
        return result
    }

    /// A small table of what tends to follow the most common English words, used until
    /// the keyboard has seen enough of this person's own typing.
    private static let commonFollowers: [String: [String]] = [
        "i": ["am", "have", "think"], "i'm": ["not", "going", "so"], "you": ["are", "can", "have"],
        "we": ["are", "can", "have"], "they": ["are", "have", "were"], "he": ["is", "was", "has"],
        "she": ["is", "was", "has"], "it": ["is", "was", "would"], "it's": ["a", "not", "the"],
        "the": ["same", "first", "best"], "a": ["lot", "few", "good"], "an": ["hour", "idea", "email"],
        "to": ["be", "the", "do"], "of": ["the", "a", "course"], "in": ["the", "a", "my"],
        "on": ["the", "my", "a"], "at": ["the", "home", "work"], "for": ["the", "a", "me"],
        "and": ["I", "the", "then"], "but": ["I", "it", "the"], "is": ["a", "the", "not"],
        "are": ["you", "we", "not"], "was": ["a", "the", "not"], "will": ["be", "have", "not"],
        "can": ["you", "I", "we"], "do": ["you", "not", "it"], "don't": ["know", "have", "think"],
        "have": ["a", "to", "been"], "thank": ["you"], "thanks": ["for", "so", "again"],
        "see": ["you", "it", "the"], "let": ["me", "us", "them"], "let's": ["go", "do", "see"],
        "how": ["are", "is", "do"], "what": ["is", "do", "are"], "good": ["morning", "night", "luck"],
        "this": ["is", "was", "one"], "that": ["is", "was", "the"], "my": ["name", "phone", "own"],
        "be": ["there", "a", "able"], "not": ["sure", "a", "the"], "going": ["to", "on", "out"],
        "want": ["to", "a", "it"], "need": ["to", "a", "it"], "with": ["the", "you", "a"]
    ]

    /// A capitalised unknown word in the middle of a sentence is most likely a name.
    private func looksLikeName(_ word: String, in context: String) -> Bool {
        guard word.first?.isUppercase == true else { return false }
        return !Self.isSentenceStart(String(context.dropLast(word.count)))
    }

    /// Real words one neighbouring key away from what was typed.
    private func neighbourWords(
        for letters: [Character], geometry: KeyGeometry, model: PersonalModelData, language: String
    ) -> [String] {
        guard letters.count >= 2, letters.count <= 12 else { return [] }
        var found: [String] = []
        for index in letters.indices {
            for neighbour in geometry.neighbours(of: letters[index]) {
                var changed = letters
                changed[index] = neighbour
                let word = String(changed)
                let range = NSRange(location: 0, length: (word as NSString).length)
                let real = model.knows(word) || checker.rangeOfMisspelledWord(
                    in: word, range: range, startingAt: 0, wrap: false, language: language
                ).location == NSNotFound
                if real { found.append(word) }
            }
        }
        return found
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
