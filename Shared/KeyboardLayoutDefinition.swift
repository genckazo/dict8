import Foundation

/// Pure layout data for the typing keyboard: rows of key characters plus the
/// accent variants offered on long press. Shared so the app can preview a layout.
struct KeyboardLayoutDefinition {
    let id: KeyboardLayoutID
    let rows: [[String]]
    /// Accents shown on long press, keyed by the base key.
    let accents: [String: [String]]
    /// Language used when the system does auto-capitalisation.
    let localeIdentifier: String

    static func definition(for id: KeyboardLayoutID) -> KeyboardLayoutDefinition {
        switch id {
        case .qwerty:
            return KeyboardLayoutDefinition(
                id: .qwerty,
                rows: [
                    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"]
                ],
                accents: [:],
                localeIdentifier: "en_US"
            )
        case .qwertz:
            return KeyboardLayoutDefinition(
                id: .qwertz,
                rows: [
                    ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["⇧", "y", "x", "c", "v", "b", "n", "m", "⌫"]
                ],
                accents: [
                    "a": ["ä", "à", "á", "â"],
                    "o": ["ö", "ô", "ó", "ò"],
                    "u": ["ü", "û", "ú", "ù"],
                    "s": ["ß", "ś", "š"]
                ],
                localeIdentifier: "de_DE"
            )
        case .turkish:
            return KeyboardLayoutDefinition(
                id: .turkish,
                rows: [
                    ["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"]
                ],
                accents: [
                    "g": ["ğ"],
                    "u": ["ü", "û"],
                    "i": ["ı", "î"],
                    "ı": ["i"],
                    "o": ["ö", "ô"],
                    "c": ["ç"],
                    "s": ["ş"]
                ],
                localeIdentifier: "tr_TR"
            )
        }
    }
}
