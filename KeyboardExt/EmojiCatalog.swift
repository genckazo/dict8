import Foundation

/// Emoji grouped for the picker, built from Unicode properties at first use so
/// the list follows whatever the OS font supports. Covers single-codepoint
/// emoji and flags; skin tones and joined family sequences are not offered.
enum EmojiCatalog {
    struct Category {
        let name: String
        let symbol: String
        let emojis: [String]
    }

    static let categories: [Category] = [
        Category(name: "Smileys & People", symbol: "face.smiling", emojis: emojis(in: [
            0x1F600...0x1F64F, 0x1F910...0x1F92F, 0x1F970...0x1F97A, 0x1F9D0...0x1F9D0, 0x1FAE0...0x1FAE8,
            0x1F90C...0x1F90F, 0x1F930...0x1F93A, 0x1F440...0x1F4A9, 0x1F9B5...0x1F9B9, 0x1F9D1...0x1F9DF,
            0x1FAC0...0x1FAC5, 0x1FAF0...0x1FAF8, 0x270A...0x270D
        ]) + ["\u{2764}\u{FE0F}"]),
        Category(name: "Animals & Nature", symbol: "leaf", emojis: emojis(in: [
            0x1F400...0x1F43F, 0x1F980...0x1F9AE, 0x1FAB0...0x1FABF, 0x1F330...0x1F343, 0x1F300...0x1F32C,
            0x2600...0x2604, 0x26A1...0x26A1, 0x2B50...0x2B50
        ])),
        Category(name: "Food & Drink", symbol: "fork.knife", emojis: emojis(in: [
            0x1F32D...0x1F32F, 0x1F345...0x1F37F, 0x1F950...0x1F96F, 0x1F9C0...0x1F9CB, 0x1FAD0...0x1FADB,
            0x2615...0x2615
        ])),
        Category(name: "Activity", symbol: "soccerball", emojis: emojis(in: [
            0x26BD...0x26BE, 0x1F380...0x1F3D3, 0x1F3F8...0x1F3F9, 0x1F93C...0x1F94F, 0x1FA70...0x1FA88,
            0x1F3AF...0x1F3AF
        ])),
        Category(name: "Travel & Places", symbol: "car", emojis: emojis(in: [
            0x1F680...0x1F6FF, 0x1F3D4...0x1F3F0, 0x1F5FA...0x1F5FF, 0x26EA...0x26FA, 0x2708...0x2708
        ])),
        Category(name: "Objects", symbol: "lightbulb", emojis: emojis(in: [
            0x231A...0x231B, 0x23E9...0x23F3, 0x1F4AA...0x1F4FF, 0x1F56F...0x1F5F4, 0x1F9E0...0x1F9FF,
            0x1FA90...0x1FAAF
        ])),
        Category(name: "Symbols", symbol: "heart", emojis: emojis(in: [
            0x1F493...0x1F49F, 0x2705...0x2705, 0x2728...0x2728, 0x274C...0x274E, 0x2753...0x2757,
            0x2795...0x2797, 0x1F500...0x1F53D, 0x1F7E0...0x1F7EB, 0x1F191...0x1F19A, 0x267F...0x267F,
            0x2648...0x2653, 0x26D4...0x26D4, 0x2B1B...0x2B1C, 0x2B55...0x2B55
        ])),
        Category(name: "Flags", symbol: "flag", emojis: flags)
    ]

    /// Emoji whose Unicode name (or country name, for flags) contains the query.
    static func search(_ query: String, limit: Int = 40) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        // Whole-word matches first ("fire" before "fireworks"), then word starts, then anything else.
        var ranked: [(emoji: String, rank: Int, length: Int)] = []
        for entry in index where entry.name.contains(needle) {
            let rank: Int
            if entry.name.split(separator: " ").contains(Substring(needle)) {
                rank = 0
            } else if entry.name.hasPrefix(needle) || entry.name.contains(" \(needle)") {
                rank = 1
            } else {
                rank = 2
            }
            ranked.append((entry.emoji, rank, entry.name.count))
        }
        ranked.sort { ($0.rank, $0.length) < ($1.rank, $1.length) }
        return ranked.prefix(limit).map(\.emoji)
    }

    private static let index: [(emoji: String, name: String)] = {
        var seen = Set<String>()
        var entries: [(String, String)] = []
        for category in categories where category.name != "Flags" {
            for emoji in category.emojis where seen.insert(emoji).inserted {
                let name = emoji.unicodeScalars.first?.properties.name?.lowercased() ?? ""
                entries.append((emoji, name))
            }
        }
        for (emoji, name) in zip(flags, flagNames) {
            entries.append((emoji, "flag \(name.lowercased())"))
        }
        return entries
    }()

    private static func emojis(in ranges: [ClosedRange<UInt32>]) -> [String] {
        var result: [String] = []
        var seen = Set<UInt32>()
        for range in ranges {
            for value in range {
                // Skin tone modifiers are not standalone emoji.
                guard !(0x1F3FB...0x1F3FF).contains(value), seen.insert(value).inserted,
                      let scalar = Unicode.Scalar(value),
                      scalar.properties.isEmoji, scalar.properties.isEmojiPresentation else { continue }
                result.append(String(Character(scalar)))
            }
        }
        return result
    }

    private static let regionCodes: [String] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
        .sorted()

    private static let flags: [String] = regionCodes.map { code in
        String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 65) }))
    }

    private static let flagNames: [String] = regionCodes.map {
        Locale(identifier: "en_US").localizedString(forRegionCode: $0) ?? $0
    }
}
