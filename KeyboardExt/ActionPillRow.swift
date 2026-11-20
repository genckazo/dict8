import UIKit

/// The row of capsule shortcuts between the suggestions and the keys.
final class ActionPillRow: UIView {
    enum Action: Int, CaseIterable {
        case proofread
        case paste
        case search
        case polish

        var symbol: String {
            switch self {
            case .proofread: return "text.badge.checkmark"
            case .paste: return "doc.on.clipboard"
            case .search: return "magnifyingglass"
            case .polish: return "sparkles"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .proofread: return "Fix spelling"
            case .paste: return "Paste"
            case .search: return "Search emoji"
            case .polish: return "Polish text"
            }
        }
    }

    var onAction: ((Action) -> Void)?
    private let buttons: [UIButton] = Action.allCases.map { _ in UIButton(type: .custom) }
    private var theme = KeyboardTheme.dark

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.001)
        let symbol = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        for (button, action) in zip(buttons, Action.allCases) {
            button.tag = action.rawValue
            button.setImage(UIImage(systemName: action.symbol, withConfiguration: symbol), for: .normal)
            button.accessibilityLabel = action.accessibilityLabel
            button.adjustsImageWhenHighlighted = false
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(highlightChanged(_:)), for: .allTouchEvents)
            addSubview(button)
        }
        apply(theme: .dark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme newTheme: KeyboardTheme) {
        theme = newTheme
        buttons.forEach {
            $0.backgroundColor = theme.key
            $0.tintColor = theme.label
        }
    }

    /// Spins the icon's opacity while a slow action (the polish request) is running.
    func setBusy(_ busy: Bool, action: Action) {
        let button = buttons[action.rawValue]
        button.isEnabled = !busy
        button.layer.removeAnimation(forKey: "busy")
        guard busy else { return button.alpha = 1 }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.35
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        button.layer.add(pulse, forKey: "busy")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 8
        let gap: CGFloat = 8
        let count = CGFloat(buttons.count)
        let width = (bounds.width - inset * 2 - gap * (count - 1)) / count
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: inset + (width + gap) * CGFloat(index), y: 0, width: width, height: bounds.height)
            button.layer.cornerRadius = bounds.height / 2
            button.layer.cornerCurve = .continuous
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        guard let action = Action(rawValue: sender.tag) else { return }
        onAction?(action)
    }

    @objc private func highlightChanged(_ sender: UIButton) {
        sender.backgroundColor = sender.isHighlighted ? theme.keyPressed : theme.key
    }
}

/// Emoji search results, shown in place of the pills while searching.
final class EmojiResultStrip: UIView {
    var onEmoji: ((String) -> Void)?
    var onClose: (() -> Void)?

    private let scrollView = UIScrollView()
    private let closeButton = UIButton(type: .custom)
    private let emptyLabel = UILabel()
    private var emojiButtons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.001)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)

        emptyLabel.text = "No emoji found"
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        addSubview(emptyLabel)

        let symbol = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        closeButton.accessibilityLabel = "Close search"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme: KeyboardTheme) {
        closeButton.backgroundColor = theme.key
        closeButton.tintColor = theme.label
        emptyLabel.textColor = theme.secondaryLabel
    }

    func show(_ emojis: [String]) {
        emojiButtons.forEach { $0.removeFromSuperview() }
        emojiButtons = emojis.map { emoji in
            let button = UIButton(type: .custom)
            button.setTitle(emoji, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 28)
            button.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
            scrollView.addSubview(button)
            return button
        }
        emptyLabel.isHidden = !emojis.isEmpty
        scrollView.contentOffset = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let close = bounds.height - 6
        closeButton.frame = CGRect(x: bounds.width - close - 8, y: 3, width: close, height: close)
        closeButton.layer.cornerRadius = close / 2
        scrollView.frame = CGRect(x: 0, y: 0, width: closeButton.frame.minX - 4, height: bounds.height)
        emptyLabel.frame = scrollView.frame
        let cell: CGFloat = 44
        for (index, button) in emojiButtons.enumerated() {
            button.frame = CGRect(x: 6 + cell * CGFloat(index), y: 0, width: cell, height: bounds.height)
        }
        scrollView.contentSize = CGSize(width: 12 + cell * CGFloat(emojiButtons.count), height: bounds.height)
    }

    @objc private func emojiTapped(_ sender: UIButton) {
        if let emoji = sender.title(for: .normal) { onEmoji?(emoji) }
    }

    @objc private func closeTapped() { onClose?() }
}
