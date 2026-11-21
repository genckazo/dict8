import Foundation

/// Tidies a finished stretch of dictation: acts on spoken commands, drops
/// filler sounds and words said twice by accident. Live text is left raw; this
/// runs once the recogniser is done with an utterance.
enum DictationFormatter {
    struct Result: Equatable {
        var text: String
        /// "Scratch that" was said with nothing before it, so it refers to what came earlier.
        var deletesPrevious = false
    }

    static func format(_ text: String, language: String) -> Result {
        var result = Result(text: text)
        if language.hasPrefix("en") { result = applyCommands(to: text) }
        result.text = removeFillers(from: result.text, language: language)
        result.text = collapseRepeats(in: result.text)
        result.text = tidy(result.text)
        return result
    }

    // MARK: - Spoken commands

    private static let commandPattern = try! NSRegularExpression(
        // "A new line of products" is talking about a line, not asking for one.
        pattern: "([,.!?]?)\\s*\\b(new paragraph|new line|newline|scratch that|delete that)\\b"
            + "(?!\\s+(?:of|for|in|item|items)\\b)[,.!?]?\\s*",
        options: [.caseInsensitive]
    )

    private static func applyCommands(to text: String) -> Result {
        let source = text as NSString
        var output = ""
        var deletesPrevious = false
        var cursor = 0
        var capitaliseNext = false
        func append(_ piece: String) {
            guard !piece.isEmpty else { return }
            output += capitaliseNext ? piece.prefix(1).uppercased() + piece.dropFirst() : piece
            capitaliseNext = false
        }
        for match in commandPattern.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            append(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
            // The sentence before a line break keeps its full stop; a comma would just dangle.
            let before = source.substring(with: match.range(at: 1))
            let ending = before == "," ? "" : before
            switch source.substring(with: match.range(at: 2)).lowercased() {
            case "new paragraph":
                output = trimmedEnd(output) + ending + "\n\n"
                capitaliseNext = true
            case "new line", "newline":
                output = trimmedEnd(output) + ending + "\n"
                capitaliseNext = true
            default:
                // Take back the sentence just spoken.
                let spoken = trimmedEnd(output)
                if spoken.isEmpty {
                    deletesPrevious = true
                    output = ""
                } else {
                    output = droppingLastSentence(spoken)
                }
                capitaliseNext = output.isEmpty || output.hasSuffix("\n")
            }
        }
        append(source.substring(from: cursor))
        return Result(text: output, deletesPrevious: deletesPrevious)
    }

    private static func trimmedEnd(_ text: String) -> String {
        var text = text
        while let last = text.last, last == " " || last == "\t" { text.removeLast() }
        return text
    }

    private static func droppingLastSentence(_ text: String) -> String {
        var characters = Array(text)
        // Ignore the full stop that ends the sentence being removed.
        while let last = characters.last, ".!?".contains(last) { characters.removeLast() }
        while let last = characters.last {
            if ".!?\n".contains(last) { break }
            characters.removeLast()
        }
        let kept = String(characters)
        return kept.isEmpty || kept.hasSuffix("\n") ? kept : kept + " "
    }

    // MARK: - Fillers and repeats

    private static func fillers(for language: String) -> [String] {
        switch language.prefix(2) {
        case "de": return ["äh+", "ähm+", "öhm+", "hm+"]
        case "tr": return ["ı{2,}", "e{3,}", "hım+"]
        default: return ["u+m+", "u+h+", "u+hm+", "erm+", "hm+", "mhm+"]
        }
    }

    private static func removeFillers(from text: String, language: String) -> String {
        let words = fillers(for: language).joined(separator: "|")
        // A filler takes its own comma with it: "so, um, yes" becomes "so, yes".
        let pattern = "(?i)(^|[\\s])(?:\(words))(?![\\p{L}'])[,.]?"
        let stripped = text.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        guard stripped != text else { return text }
        // If the sentence opened with the filler, the next word now starts it.
        var characters = Array(stripped)
        if text.first?.isUppercase == true,
           let first = characters.firstIndex(where: { !$0.isWhitespace }), characters[first].isLowercase {
            characters[first] = Character(String(characters[first]).uppercased())
        }
        return String(characters)
    }

    /// Pairs that are said twice on purpose.
    private static let allowedRepeats: Set<String> = [
        "had", "that", "very", "so", "no", "bye", "ha", "really", "many", "long", "far", "is", "na", "yeah"
    ]
    private static let repeatPattern = try! NSRegularExpression(pattern: "\\b([\\p{L}']+)(?:\\s+\\1\\b)+", options: [.caseInsensitive])

    private static func collapseRepeats(in text: String) -> String {
        let source = text as NSString
        var output = ""
        var cursor = 0
        for match in repeatPattern.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            let word = source.substring(with: match.range(at: 1))
            guard !allowedRepeats.contains(word.lowercased()) else { continue }
            output += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)) + word
            cursor = match.range.location + match.range.length
        }
        return output + source.substring(from: cursor)
    }

    private static func tidy(_ text: String) -> String {
        var text = text
        for (pattern, replacement) in [("[ \\t]{2,}", " "), (" +([,.;:!?])", "$1"), ("^[ \\t,]+", ""), ("\\n[ \\t]+", "\n")] {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return text
    }
}
