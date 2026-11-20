import UIKit

/// A single keyboard key. Handles press feedback, optional auto-repeat
/// (backspace) and the long-press accent menu.
final class KeyButton: UIButton {
    enum Style {
        case character
        case special
        case shift
        case delete
        case space
    }

    var style: Style = .character
    var keyValue: String = ""
    /// Called repeatedly while the key is held. The argument counts repeats so far.
    var repeatAction: ((Int) -> Void)?
    var onTap: ((KeyButton) -> Void)?
    /// How far the touch target reaches past the drawn key, so the gaps between
    /// keys still register on the nearest one.
    var touchOutsets: UIEdgeInsets = .zero
    var theme: KeyboardTheme = .dark {
        didSet { applyColors() }
    }

    private var repeatTimer: Timer?
    private var repeatDelay: DispatchWorkItem?
    private var repeatCount = 0
    private var didRepeat = false

    override var isHighlighted: Bool {
        didSet { applyColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.font = .systemFont(ofSize: 23, weight: .regular)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.6
        adjustsImageWhenHighlighted = false
        layer.cornerRadius = 5.5
        layer.cornerCurve = .continuous
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

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let reach = UIEdgeInsets(
            top: -touchOutsets.top, left: -touchOutsets.left,
            bottom: -touchOutsets.bottom, right: -touchOutsets.right
        )
        return bounds.inset(by: reach).contains(point)
    }

    func setSymbol(_ name: String, pointSize: CGFloat = 20, weight: UIImage.SymbolWeight = .regular) {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        setTitle(nil, for: .normal)
        setImage(UIImage(systemName: name, withConfiguration: configuration), for: .normal)
    }

    func setLabel(_ text: String, size: CGFloat = 23) {
        setImage(nil, for: .normal)
        titleLabel?.font = .systemFont(ofSize: size, weight: .regular)
        setTitle(text, for: .normal)
    }

    func applyColors() {
        backgroundColor = isHighlighted ? theme.keyPressed : theme.key
        setTitleColor(theme.label, for: .normal)
        tintColor = theme.label
    }

    @objc private func pressDown() {
        pressUp()
        didRepeat = false
        guard repeatAction != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.repeatCount = 0
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.didRepeat = true
                self.repeatAction?(self.repeatCount)
                self.repeatCount += 1
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
        // A hold that already repeated must not act once more on release.
        guard !didRepeat else { return }
        onTap?(self)
    }
}
