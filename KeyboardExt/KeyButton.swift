import UIKit

/// A single keyboard key. Handles press feedback, optional auto-repeat
/// (backspace) and the long-press accent menu.
final class KeyButton: UIButton {
    enum Style {
        case character
        case special
        case shift
        case delete
        case mic
        case action
    }

    var style: Style = .character
    var keyValue: String = ""
    var repeatAction: (() -> Void)?
    var onTap: ((KeyButton) -> Void)?
    var keyboardAppearance: KeyboardAppearanceID = .system {
        didSet { applyColors() }
    }

    private var repeatTimer: Timer?
    private var repeatDelay: DispatchWorkItem?
    private let impact = UIImpactFeedbackGenerator(style: .light)

    override var isHighlighted: Bool {
        didSet { applyColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.6
        layer.cornerRadius = 9
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        translatesAutoresizingMaskIntoConstraints = true
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        repeatDelay?.cancel()
        repeatTimer?.invalidate()
    }

    func applyColors() {
        let dark: Bool = {
            switch keyboardAppearance {
            case .dark: return true
            case .light: return false
            case .system: return traitCollection.userInterfaceStyle == .dark
            }
        }()

        let background: UIColor
        let foreground: UIColor
        switch style {
        case .character, .action:
            background = dark ? UIColor(white: 0.23, alpha: 1) : .white
            foreground = dark ? .white : .black
        case .special:
            background = dark ? UIColor(white: 0.29, alpha: 1) : UIColor(white: 0.82, alpha: 1)
            foreground = dark ? .white : .black
        case .shift:
            background = dark ? UIColor(white: 0.29, alpha: 1) : UIColor(white: 0.82, alpha: 1)
            foreground = dark ? .white : .black
        case .delete:
            background = dark ? UIColor(white: 0.29, alpha: 1) : UIColor(white: 0.82, alpha: 1)
            foreground = dark ? .white : .black
        case .mic:
            background = isRecording ? .systemRed : UIColor(white: dark ? 0.29 : 0.82, alpha: 1)
            foreground = isRecording ? .white : (dark ? .white : .black)
        }
        backgroundColor = isHighlighted ? background.withAlphaComponent(0.55) : background
        setTitleColor(foreground, for: .normal)
        tintColor = foreground
    }

    var isRecording = false {
        didSet { applyColors() }
    }

    @objc private func pressDown() {
        pressUp()
        guard repeatAction != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.repeatAction?()
            }
        }
        repeatDelay = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    @objc private func pressUp() {
        repeatDelay?.cancel()
        repeatDelay = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    @objc private func tapped() {
        onTap?(self)
    }
}
