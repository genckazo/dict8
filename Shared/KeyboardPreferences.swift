import Foundation
import SwiftUI

/// Settings shared by the containing app and the keyboard extension.
///
/// Both processes read the same `UserDefaults` suite. When the App Group
/// entitlement is unavailable (for example under a free provisioning profile),
/// the code falls back to the process-local defaults so nothing crashes.
enum KeyboardPreferences {
    static let appGroup = "group.com.kazo.voicekeyboard"

    static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    enum Key {
        static let layout = "kb.layout"
        static let haptics = "kb.haptics"
        static let sounds = "kb.sounds"
        static let autoCapitalize = "kb.autoCapitalize"
        static let dictationLocale = "kb.dictationLocale"
        static let recentEmojis = "kb.recentEmojis"
        static let onDeviceDictation = "kb.onDeviceDictation"
        static let hasCompletedOnboarding = "app.onboarded"
    }

    static var layout: KeyboardLayoutID {
        get { KeyboardLayoutID(rawValue: store.string(forKey: Key.layout) ?? "") ?? .qwerty }
        set { store.set(newValue.rawValue, forKey: Key.layout) }
    }

    static var haptics: Bool {
        get { store.object(forKey: Key.haptics) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.haptics) }
    }

    static var sounds: Bool {
        get { store.object(forKey: Key.sounds) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.sounds) }
    }

    static var autoCapitalize: Bool {
        get { store.object(forKey: Key.autoCapitalize) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.autoCapitalize) }
    }

    static var dictationLocale: String {
        get { store.string(forKey: Key.dictationLocale) ?? Locale.current.identifier }
        set { store.set(newValue, forKey: Key.dictationLocale) }
    }

    /// Off by default: speech goes to Apple's servers, which is quicker and more accurate.
    static var onDeviceDictation: Bool {
        get { store.bool(forKey: Key.onDeviceDictation) }
        set { store.set(newValue, forKey: Key.onDeviceDictation) }
    }

    static var recentEmojis: [String] {
        get { store.stringArray(forKey: Key.recentEmojis) ?? [] }
        set { store.set(Array(newValue.prefix(24)), forKey: Key.recentEmojis) }
    }

    static var hasCompletedOnboarding: Bool {
        get { store.bool(forKey: Key.hasCompletedOnboarding) }
        set { store.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}

enum KeyboardLayoutID: String, CaseIterable, Identifiable {
    case qwerty
    case qwertz
    case turkish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwerty: return "QWERTY (English)"
        case .qwertz: return "QWERTZ (German)"
        case .turkish: return "QWERTY (Turkish)"
        }
    }

    var shortName: String {
        switch self {
        case .qwerty: return "EN"
        case .qwertz: return "DE"
        case .turkish: return "TR"
        }
    }
}
