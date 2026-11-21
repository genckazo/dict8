import CoreGraphics
import Foundation

/// What the keyboard has learned about one person's typing. Everything here
/// stays on the device, in the keyboard's own preferences.
struct PersonalModelData: Codable {
    /// Where taps meant for a key land, relative to its centre, in key widths and heights.
    struct TapStat: Codable {
        var dx: Double = 0
        var dy: Double = 0
        var count: Int = 0
    }

    /// Lowercased word → how many times it was typed and kept.
    var words: [String: Int] = [:]
    /// Words the dictionary does not know that this person uses on purpose.
    var learned: Set<String> = []
    /// Typed words whose autocorrection was undone; they are left alone from then on.
    var rejected: Set<String> = []
    /// Lowercased letter → average tap offset.
    var taps: [String: TapStat] = [:]

    static let tapSamplesBeforeUse = 25

    func count(of word: String) -> Int { words[word.lowercased()] ?? 0 }
    func knows(_ word: String) -> Bool { learned.contains(word.lowercased()) }
    func isRejected(_ word: String) -> Bool { rejected.contains(word.lowercased()) }

    /// The learned offset for a key, once there are enough taps to trust it.
    func offset(for letter: Character) -> CGPoint {
        guard let stat = taps[String(letter).lowercased()], stat.count >= Self.tapSamplesBeforeUse else { return .zero }
        return CGPoint(x: stat.dx, y: stat.dy)
    }

    /// Learned words starting with `prefix`, most used first.
    func completions(for prefix: String, limit: Int) -> [String] {
        let needle = prefix.lowercased()
        guard needle.count >= 2 else { return [] }
        return words
            .filter { $0.value >= 2 && $0.key.count > needle.count && $0.key.hasPrefix(needle) }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(limit)
            .map(\.key)
    }

    mutating func noteWord(_ word: String, knownToDictionary: Bool) {
        let key = word.lowercased()
        guard key.count >= 2, key.count <= 32 else { return }
        words[key, default: 0] += 1
        // An unknown word typed twice and kept both times is one of theirs.
        if !knownToDictionary, words[key, default: 0] >= 2 { learned.insert(key) }
        if words.count > 4000 { words = words.filter { $0.value > 1 } }
    }

    mutating func keep(_ word: String) {
        let key = word.lowercased()
        learned.insert(key)
        rejected.insert(key)
        words[key, default: 0] += 1
    }

    /// Folds one tap into the running average for the key it was meant for.
    mutating func noteTap(for letter: Character, dx: Double, dy: Double) {
        // A tap more than a key away says nothing about how this key is aimed at.
        guard abs(dx) < 1.2, abs(dy) < 1.2 else { return }
        let key = String(letter).lowercased()
        var stat = taps[key] ?? TapStat()
        // Recent typing counts for more, so the model follows a change of grip.
        let weight = 1.0 / Double(min(stat.count + 1, 200))
        stat.dx += (dx - stat.dx) * weight
        stat.dy += (dy - stat.dy) * weight
        stat.dx = min(max(stat.dx, -0.3), 0.3)
        stat.dy = min(max(stat.dy, -0.3), 0.3)
        stat.count += 1
        taps[key] = stat
    }
}

/// Loads and saves the personal model. Main thread only; background work gets a copy of `data`.
final class PersonalModel {
    private(set) var data = PersonalModelData()
    private var unsavedChanges = 0

    init() { reload() }

    /// Picks up a reset made in the dict8 app while the keyboard was away.
    func reload() {
        guard unsavedChanges == 0 else { return }
        guard let stored = KeyboardPreferences.personalModel,
              let decoded = try? JSONDecoder().decode(PersonalModelData.self, from: stored) else {
            data = PersonalModelData()
            return
        }
        data = decoded
    }

    func update(_ change: (inout PersonalModelData) -> Void) {
        change(&data)
        unsavedChanges += 1
        if unsavedChanges >= 20 { save() }
    }

    func save() {
        guard unsavedChanges > 0, let encoded = try? JSONEncoder().encode(data) else { return }
        KeyboardPreferences.personalModel = encoded
        unsavedChanges = 0
    }
}
