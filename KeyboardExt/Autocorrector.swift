import CoreGraphics
import Foundation

/// One typed letter and, when it came from a key tap, where the finger landed.
struct TypedLetter {
    let character: Character
    let point: CGPoint?
}

/// Where the letter keys are, so a tap can be compared with the keys around it.
struct KeyGeometry {
    var centers: [Character: CGPoint] = [:]
    var keyWidth: CGFloat = 33.5
    var keyHeight: CGFloat = 54

    /// Letters whose keys touch `letter`'s key, including diagonals.
    func neighbours(of letter: Character) -> [Character] {
        guard let centre = centers[letter] else { return [] }
        return centers.compactMap { other, point in
            guard other != letter else { return nil }
            let dx = (point.x - centre.x) / keyWidth
            let dy = (point.y - centre.y) / keyHeight
            return (dx * dx + dy * dy).squareRoot() < 1.35 ? other : nil
        }
    }
}

/// Picks the word someone most likely meant. A mistake that is easy to make on
/// this keyboard (the next key over, two letters swapped) costs less than one
/// that is not, and the person's own tap habits and vocabulary tip the balance.
enum Autocorrector {
    /// Returns the best candidate, or nil when none is close enough to replace what was typed.
    static func correction(
        for typed: [TypedLetter], candidates: [String], geometry: KeyGeometry, model: PersonalModelData
    ) -> String? {
        guard typed.count >= 2, typed.count <= 24 else { return nil }
        let typedWord = String(typed.map(\.character)).lowercased()
        var best: (word: String, score: Double)?
        var seen = Set<String>()
        for (rank, candidate) in candidates.enumerated() {
            let lowered = candidate.lowercased()
            guard lowered != typedWord, seen.insert(lowered).inserted,
                  !candidate.contains(" "), !candidate.contains("-") else { continue }
            let distance = cost(typed: typed, candidate: Array(lowered), geometry: geometry, model: model)
            // Their own words win ties; the dictionary's order breaks the rest.
            let familiarity = min(0.4, 0.12 * log2(1 + Double(model.count(of: lowered))))
            let score = distance - familiarity + 0.06 * Double(min(rank, 6))
            if best == nil || score < best!.score { best = (candidate, score) }
        }
        // Longer words can absorb more slips before the guess stops being safe.
        let limit = min(0.45 * Double(typed.count), 2.0)
        guard let best, best.score <= limit else { return nil }
        return matchCase(of: typed, in: best.word)
    }

    /// Weighted edit distance between what was typed and a candidate word.
    static func cost(
        typed: [TypedLetter], candidate: [Character], geometry: KeyGeometry, model: PersonalModelData
    ) -> Double {
        let letters = typed.map { Character(String($0.character).lowercased()) }
        let n = letters.count, m = candidate.count
        guard n > 0 else { return Double(m) }
        guard m > 0 else { return Double(n) }
        var table = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        for i in 1...n { table[i][0] = Double(i) }
        for j in 1...m { table[0][j] = table[0][j - 1] + insertionCost(candidate, at: j - 1) }
        for i in 1...n {
            for j in 1...m {
                let swap = substitutionCost(typed[i - 1], letters[i - 1], candidate[j - 1], geometry, model)
                // A letter typed twice by accident is a smaller slip than a stray one.
                let extra = i > 1 && letters[i - 1] == letters[i - 2] ? 0.5 : 0.9
                var value = min(
                    table[i - 1][j - 1] + swap,
                    table[i - 1][j] + extra,
                    table[i][j - 1] + insertionCost(candidate, at: j - 1)
                )
                if i > 1, j > 1, letters[i - 1] == candidate[j - 2], letters[i - 2] == candidate[j - 1],
                   letters[i - 1] != letters[i - 2] {
                    value = min(value, table[i - 2][j - 2] + 0.6)
                }
                table[i][j] = value
            }
        }
        return table[n][m]
    }

    /// The cost of a letter the word needs but that was not typed. A left-out apostrophe is
    /// the cheapest slip there is, and a double letter typed once comes next.
    private static func insertionCost(_ candidate: [Character], at index: Int) -> Double {
        let character = candidate[index]
        if character == "'" || character == "’" { return 0.3 }
        let doubled = (index > 0 && candidate[index - 1] == character)
            || (index + 1 < candidate.count && candidate[index + 1] == character)
        return doubled ? 0.5 : 0.9
    }

    private static func substitutionCost(
        _ tap: TypedLetter, _ typed: Character, _ wanted: Character, _ geometry: KeyGeometry, _ model: PersonalModelData
    ) -> Double {
        if typed == wanted { return 0 }
        // ü typed as u, ç as c: the same key held a moment longer.
        if fold(typed) == fold(wanted) { return 0.2 }
        guard let wantedCentre = geometry.centers[wanted],
              let point = tap.point ?? geometry.centers[typed] else { return 1 }
        let offset = model.offset(for: wanted)
        let dx = Double((point.x - wantedCentre.x) / geometry.keyWidth) - Double(offset.x)
        let dy = Double((point.y - wantedCentre.y) / geometry.keyHeight) - Double(offset.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        // A tap on the shared edge of two keys is nearly free; a key further away costs full price.
        return min(max(distance / 1.6, 0.25), 1)
    }

    private static func fold(_ character: Character) -> String {
        String(character).folding(options: .diacriticInsensitive, locale: nil)
    }

    private static func matchCase(of typed: [TypedLetter], in word: String) -> String {
        let characters = typed.map(\.character)
        if characters.count > 1, characters.allSatisfy({ !$0.isLetter || $0.isUppercase }) { return word.uppercased() }
        if characters.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }
}
