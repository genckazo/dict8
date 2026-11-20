import UIKit

/// Colours for the keyboard chrome. The keyboard itself draws no background:
/// the system backdrop shows through, so the keys sit on the same surface as
/// the globe strip iOS draws underneath.
struct KeyboardTheme: Equatable {
    let isDark: Bool
    let key: UIColor
    let keyPressed: UIColor
    let label: UIColor
    let secondaryLabel: UIColor
    let divider: UIColor
    let voiceFill: UIColor
    let voiceIcon: UIColor
    let panel: UIColor

    static let recording = UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1)

    static let dark = KeyboardTheme(
        isDark: true,
        key: UIColor(red: 0.271, green: 0.271, blue: 0.278, alpha: 1),
        keyPressed: UIColor(red: 0.42, green: 0.42, blue: 0.43, alpha: 1),
        label: .white,
        secondaryLabel: UIColor(white: 0.62, alpha: 1),
        divider: UIColor(white: 1, alpha: 0.14),
        voiceFill: .white,
        voiceIcon: .black,
        panel: UIColor(red: 0.169, green: 0.169, blue: 0.176, alpha: 1)
    )

    static let light = KeyboardTheme(
        isDark: false,
        key: .white,
        keyPressed: UIColor(red: 0.78, green: 0.79, blue: 0.82, alpha: 1),
        label: .black,
        secondaryLabel: UIColor(white: 0.38, alpha: 1),
        divider: UIColor(white: 0, alpha: 0.16),
        voiceFill: .black,
        voiceIcon: .white,
        panel: UIColor(red: 0.82, green: 0.83, blue: 0.86, alpha: 1)
    )
}

/// Sizes that change between portrait and landscape.
struct KeyboardMetrics {
    let height: CGFloat
    let topBarY: CGFloat
    let topBarHeight: CGFloat
    let showsPills: Bool
    let pillY: CGFloat
    let pillHeight: CGFloat
    let keysY: CGFloat
    let rowPitch: CGFloat
    let rowGap: CGFloat

    /// Measured from the reference at 402 pt wide: 42.3 pt keys on a 54 pt pitch.
    /// From iOS 26 the system backdrop already leaves about 15 pt above the
    /// keyboard's own view, so the top padding is only needed before that.
    static let portrait: KeyboardMetrics = {
        let pad: CGFloat
        if #available(iOS 26.0, *) { pad = 0 } else { pad = 13 }
        return KeyboardMetrics(
            height: pad + 319, topBarY: pad, topBarHeight: 56, showsPills: true, pillY: pad + 58, pillHeight: 40,
            keysY: pad + 102.5, rowPitch: 54, rowGap: 11.7
        )
    }()

    static let landscape = KeyboardMetrics(
        height: 206, topBarY: 2, topBarHeight: 40, showsPills: false, pillY: 42, pillHeight: 0,
        keysY: 44, rowPitch: 40, rowGap: 6
    )
}
