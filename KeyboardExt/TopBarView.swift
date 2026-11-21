import UIKit

/// The strip above the keys: menu button, three word suggestions, voice button.
/// The middle section is reused for the live waveform, status messages and the
/// emoji search query.
final class TopBarView: UIView {
    var onMenu: (() -> Void)?
    var onVoice: (() -> Void)?
    var onSuggestion: ((Int) -> Void)?

    private let menuButton = UIButton(type: .custom)
    private let voiceButton = UIButton(type: .custom)
    private let suggestionButtons = (0..<3).map { _ in UIButton(type: .custom) }
    private let dividers = (0..<2).map { _ in UIView() }
    private let statusLabel = UILabel()
    private let waveform = WaveformView()
    private let timerLabel = UILabel()

    private var theme = KeyboardTheme.dark
    private var suggestions: [String] = []
    private var emphasised: Int?
    private var transientStatus: String?
    private var statusReset: DispatchWorkItem?
    private var searchText: String?
    private(set) var isRecording = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.001)

        let menuSymbol = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        menuButton.setImage(UIImage(systemName: "square.grid.2x2.fill", withConfiguration: menuSymbol), for: .normal)
        menuButton.accessibilityLabel = "Keyboard settings"
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        addSubview(menuButton)

        voiceButton.accessibilityLabel = "Dictate"
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        addSubview(voiceButton)

        for (index, button) in suggestionButtons.enumerated() {
            button.tag = index
            button.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            addSubview(button)
        }
        dividers.forEach { addSubview($0) }

        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.7
        statusLabel.numberOfLines = 2
        addSubview(statusLabel)

        timerLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        timerLabel.textAlignment = .right
        addSubview(timerLabel)
        addSubview(waveform)

        apply(theme: .dark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Content

    /// `emphasised` marks the word autocorrect will type when the word is finished.
    func setSuggestions(_ words: [String], emphasised index: Int? = nil) {
        suggestions = Array(words.prefix(3))
        emphasised = index
        render()
    }

    /// Shows a short message in place of the suggestions, then goes back.
    func flashStatus(_ text: String, seconds: TimeInterval = 2.5) {
        statusReset?.cancel()
        transientStatus = text
        render()
        let work = DispatchWorkItem { [weak self] in
            self?.transientStatus = nil
            self?.render()
        }
        statusReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func setRecording(_ recording: Bool) {
        guard recording != isRecording else { return }
        isRecording = recording
        if recording {
            statusReset?.cancel()
            transientStatus = nil
            waveform.reset()
            timerLabel.text = "0:00"
        }
        voiceButton.accessibilityLabel = recording ? "Stop dictation" : "Dictate"
        render()
    }

    func updateLevel(_ rms: Float, seconds: Double) {
        waveform.push(CGFloat(rms))
        let whole = Int(seconds)
        timerLabel.text = String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// Non-nil while the keys are typing into the emoji search instead of the document.
    func setSearch(_ text: String?) {
        searchText = text
        render()
    }

    func apply(theme newTheme: KeyboardTheme) {
        theme = newTheme
        menuButton.tintColor = theme.label
        suggestionButtons.forEach {
            $0.setTitleColor(theme.secondaryLabel, for: .normal)
            $0.setTitleColor(theme.label, for: .highlighted)
        }
        dividers.forEach { $0.backgroundColor = theme.divider }
        statusLabel.textColor = theme.secondaryLabel
        timerLabel.textColor = theme.secondaryLabel
        waveform.barColor = theme.label
        render()
    }

    private func render() {
        let showsSearch = searchText != nil && transientStatus == nil && !isRecording
        let showsStatus = transientStatus != nil || showsSearch
        let showsWave = isRecording && transientStatus == nil
        let showsWords = !showsStatus && !showsWave

        statusLabel.isHidden = !showsStatus
        if let transientStatus {
            statusLabel.text = transientStatus
        } else if let searchText {
            statusLabel.text = searchText.isEmpty ? "Search emoji" : "Search: \(searchText)"
        }
        waveform.isHidden = !showsWave
        timerLabel.isHidden = !showsWave
        dividers.forEach { $0.isHidden = !showsWords }
        for (index, button) in suggestionButtons.enumerated() {
            let word = index < suggestions.count ? suggestions[index] : ""
            button.setTitle(word, for: .normal)
            let strong = index == emphasised
            button.setTitleColor(strong ? theme.label : theme.secondaryLabel, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18, weight: strong ? .medium : .regular)
            button.isHidden = !showsWords
            button.isEnabled = !word.isEmpty
        }

        let symbol = UIImage.SymbolConfiguration(pointSize: isRecording ? 13 : 16, weight: .semibold)
        voiceButton.setImage(
            UIImage(systemName: isRecording ? "stop.fill" : "waveform", withConfiguration: symbol), for: .normal
        )
        voiceButton.backgroundColor = isRecording ? KeyboardTheme.recording : theme.voiceFill
        voiceButton.tintColor = isRecording ? .white : theme.voiceIcon
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.midY
        let circle = min(36, bounds.height - 4)
        menuButton.frame = CGRect(x: 7, y: midY - 22, width: 44, height: 44)
        voiceButton.frame = CGRect(x: bounds.width - 30 - circle / 2, y: midY - circle / 2, width: circle, height: circle)
        voiceButton.layer.cornerRadius = circle / 2

        let area = CGRect(x: 57, y: 0, width: max(bounds.width - 114, 0), height: bounds.height)
        let third = area.width / 3
        for (index, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(x: area.minX + third * CGFloat(index), y: 0, width: third, height: bounds.height)
        }
        let dividerHeight = min(32, bounds.height - 8)
        for (index, divider) in dividers.enumerated() {
            divider.frame = CGRect(
                x: area.minX + third * CGFloat(index + 1), y: midY - dividerHeight / 2,
                width: 1 / max(traitCollection.displayScale, 1), height: dividerHeight
            )
        }
        statusLabel.frame = area.insetBy(dx: 4, dy: 0)
        timerLabel.frame = CGRect(x: area.maxX - 48, y: 0, width: 44, height: bounds.height)
        waveform.frame = CGRect(x: area.minX + 4, y: midY - 14, width: max(area.width - 60, 0), height: 28)
    }

    /// The voice button is small; let touches around it count.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if voiceButton.frame.insetBy(dx: -10, dy: -12).contains(point) { return voiceButton }
        return super.hitTest(point, with: event)
    }

    @objc private func menuTapped() { onMenu?() }
    @objc private func voiceTapped() { onVoice?() }
    @objc private func suggestionTapped(_ sender: UIButton) { onSuggestion?(sender.tag) }
}

/// Scrolling level meter drawn while dictation is recording.
final class WaveformView: UIView {
    var barColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    private var levels: [CGFloat] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset() {
        levels.removeAll()
        setNeedsDisplay()
    }

    func push(_ rms: CGFloat) {
        // Speech RMS sits well under 0.2; scale it so normal talking fills the height.
        levels.append(min(max(rms * 7, 0.06), 1))
        let capacity = Int(bounds.width / 5) + 1
        if levels.count > capacity { levels.removeFirst(levels.count - capacity) }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        barColor.setFill()
        let pitch: CGFloat = 5
        let barWidth: CGFloat = 3
        var x = bounds.width - barWidth
        for level in levels.reversed() {
            guard x >= 0 else { break }
            let height = max(bounds.height * level, 3)
            let bar = CGRect(x: x, y: (bounds.height - height) / 2, width: barWidth, height: height)
            UIBezierPath(roundedRect: bar, cornerRadius: barWidth / 2).fill()
            x -= pitch
        }
    }
}
