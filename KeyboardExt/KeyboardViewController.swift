import AVFoundation
import AudioToolbox
import OSLog
import Speech
import UIKit

private let log = Logger(subsystem: "com.kazo.voicekeyboard.keyboard", category: "keyboard")

@objc(KeyboardViewController)
final class KeyboardViewController: UIInputViewController {

    // MARK: - State

    private enum Page { case letters, numbers, symbols }
    private enum ShiftState { case off, once, caps }

    private var page: Page = .letters
    private var shift: ShiftState = .off
    private var layoutID: KeyboardLayoutID = .qwerty
    private var appearance: KeyboardAppearanceID = .system

    private var definition = KeyboardLayoutDefinition.definition(for: .qwerty)
    private var heightConstraint: NSLayoutConstraint?
    private let impact = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Views

    private let rootStack = UIStackView()
    private let topBar = UIView()
    private let statusLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let row1 = KeyRowView()
    private let row2 = KeyRowView()
    private let row3 = KeyRowView()
    private let row4 = KeyRowView()
    private let settingsPanel = UIView()
    private var micKey: KeyButton?

    // MARK: - Dictation

    private let capture = WebAudioCapture()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: WebAudioCapture.sampleRate, channels: 1, interleaved: true
    )!
    private var insertedPartial = ""
    private var capturedSamples = 0
    private var speechError: String?
    private var usingOnDevice = false
    private var speechRecognizer: SFSpeechRecognizer?
    private var didFallBackToNetwork = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
        configureHierarchy()
        configureDictation()
        buildSettingsPanel()
        buildKeys()
        updateReturnKey()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPreferences()
        page = .letters
        buildKeys()
        setShift(shift)
        updateShiftForContext()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if capture.isCapturing { stopDictation() }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isLandscape = size.width > size.height
        heightConstraint?.constant = isLandscape ? 236 : 292
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateReturnKey()
        updateShiftForContext()
    }

    private func loadPreferences() {
        layoutID = KeyboardPreferences.layout
        appearance = KeyboardPreferences.appearance
        definition = KeyboardLayoutDefinition.definition(for: layoutID)
        overrideUserInterfaceStyle = appearance.interfaceStyle
    }

    // MARK: - View setup

    private func configureHierarchy() {
        view.backgroundColor = .clear

        let height = view.heightAnchor.constraint(equalToConstant: 292)
        height.priority = .init(999)
        height.isActive = true
        heightConstraint = height

        rootStack.axis = .vertical
        rootStack.spacing = 7
        rootStack.distribution = .fill
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.7
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.setImage(UIImage(systemName: "gearshape", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        settingsButton.accessibilityLabel = "Keyboard settings"

        topBar.addSubview(statusLabel)
        topBar.addSubview(settingsButton)
        topBar.heightAnchor.constraint(equalToConstant: 30).isActive = true
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -44),
            statusLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -10),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 26),
            settingsButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        [topBar, row1, row2, row3, row4].forEach { rootStack.addArrangedSubview($0) }
        row2.heightAnchor.constraint(equalTo: row1.heightAnchor).isActive = true
        row3.heightAnchor.constraint(equalTo: row1.heightAnchor).isActive = true
        row4.heightAnchor.constraint(equalTo: row1.heightAnchor, multiplier: 1.15).isActive = true
        statusLabel.text = "dict8"
    }

    private func buildKeys() {
        switch page {
        case .letters: buildLetterRows()
        case .numbers: buildNumberRows()
        case .symbols: buildSymbolRows()
        }
        buildBottomRow()
        applyAppearance()
    }

    // MARK: - Key rows

    private func buildLetterRows() {
        let rows = definition.rows
        configure(row: row1, characters: rows[0], weights: Array(repeating: 1, count: rows[0].count))
        configure(row: row2, characters: rows[1], weights: Array(repeating: 1, count: rows[1].count), inset: true)
        configure(row: row3, characters: rows[2], weights: rows[2].map { ["⇧", "⌫"].contains($0) ? 1.45 : 1 })
    }

    private func buildNumberRows() {
        configure(row: row1, characters: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], weights: Array(repeating: 1, count: 10))
        configure(row: row2, characters: ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""], weights: Array(repeating: 1, count: 10), inset: true)
        configure(row: row3, characters: ["#+=", ".", ",", "?", "!", "'", "⌫"], weights: [1.4, 1, 1, 1, 1, 1, 1.4])
    }

    private func buildSymbolRows() {
        configure(row: row1, characters: ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], weights: Array(repeating: 1, count: 10))
        configure(row: row2, characters: ["_", "\\", "|", "~", "<", ">", "£", "¥", "•", "·"], weights: Array(repeating: 1, count: 10), inset: true)
        configure(row: row3, characters: ["123", "$", "€", "©", "®", "™", "⌫"], weights: [1.4, 1, 1, 1, 1, 1, 1.4])
    }

    private func configure(row: KeyRowView, characters: [String], weights: [CGFloat], inset: Bool = false) {
        var keys: [KeyButton] = []
        for character in characters {
            let key = makeKey(character)
            switch character {
            case "⇧": key.style = .shift
            case "⌫":
                key.style = .delete
                key.repeatAction = { [weak self] in
                    guard let self else { return }
                    self.textDocumentProxy.deleteBackward()
                    self.updateShiftForContext()
                }
            case "space", "return", "🌐", "123", "ABC", "#+=": key.style = .special
            default: key.style = .character
            }
            key.applyColors()
            keys.append(key)
            if let accents = definition.accents[character.lowercased()], !accents.isEmpty {
                key.menu = accentMenu(for: key, base: character, accents: accents)
                key.showsMenuAsPrimaryAction = false
            }
        }
        row.horizontalInset = inset ? 12 : 0
        row.setKeys(keys, weights: weights)
    }

    private func buildBottomRow() {
        let numberKey = makeKey(page == .letters ? "123" : "ABC")
        numberKey.style = .special
        let globeKey = makeKey("🌐")
        globeKey.style = .special
        globeKey.isHidden = !needsInputModeSwitchKey
        globeKey.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let mic = makeKey("🎤")
        mic.style = .mic
        mic.isRecording = capture.isCapturing
        micKey = mic

        let space = makeKey("space")
        space.style = .character
        space.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)

        let returnKey = makeKey(returnKeyLabel)
        returnKey.style = .special
        returnKey.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)

        row4.horizontalInset = 0
        row4.setKeys([numberKey, globeKey, mic, space, returnKey], weights: [1.2, 1.1, 1.2, 4.4, 1.7])
        row4.keys.forEach { $0.applyColors() }
        applyAppearance()
    }

    private var returnKeyLabel: String {
        guard page == .letters else { return "return" }
        switch textDocumentProxy.returnKeyType {
        case .go: return "go"
        case .google: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .search: return "search"
        case .send: return "send"
        case .yahoo: return "search"
        case .done: return "done"
        case .emergencyCall: return "call"
        case .continue: return "continue"
        default: return "return"
        }
    }

    private func updateReturnKey() {
        guard page == .letters, let key = row4.keys.last else { return }
        key.setTitle(returnKeyLabel, for: .normal)
    }

    private func makeKey(_ title: String) -> KeyButton {
        let key = KeyButton()
        key.keyValue = title
        key.setTitle(title, for: .normal)
        key.keyboardAppearance = appearance
        key.onTap = { [weak self] tapped in self?.handleTap(tapped) }
        return key
    }

    private func accentMenu(for key: KeyButton, base: String, accents: [String]) -> UIMenu {
        let actions = accents.map { accent in
            UIAction(title: accent) { [weak self] _ in
                guard let self else { return }
                self.feedback()
                let accented = self.shift != .off
                    ? accent.uppercased(with: Locale(identifier: self.definition.localeIdentifier))
                    : accent
                self.textDocumentProxy.insertText(accented)
                if self.shift == .once { self.setShift(.off) }
            }
        }
        return UIMenu(title: base, children: actions)
    }

    // MARK: - Tap handling

    private func handleTap(_ key: KeyButton) {
        feedback()
        switch key.keyValue {
        case "⇧":
            switch shift {
            case .off: setShift(.once)
            case .once: setShift(.caps)
            case .caps: setShift(.off)
            }
        case "⌫":
            textDocumentProxy.deleteBackward()
            updateShiftForContext()
        case "🌐":
            break // handled by the input mode target
        case "🎤":
            toggleDictation()
        case "space":
            insertText(" ")
        case "return":
            insertText("\n")
        case "123":
            page = .numbers
            buildKeys()
        case "#+=":
            page = .symbols
            buildKeys()
        case "ABC":
            page = .letters
            buildKeys()
        default:
            insertText(key.keyValue)
        }
    }

    private func insertText(_ text: String) {
        var output = text
        if page == .letters, shift != .off, text.count == 1 {
            output = text.uppercased(with: Locale(identifier: definition.localeIdentifier))
        }
        textDocumentProxy.insertText(output)
        if shift == .once { setShift(.off) }
        updateShiftForContext()
    }

    private func setShift(_ state: ShiftState) {
        shift = state
        if state == .off || state == .once {
            row3.keys.first?.setTitle("⇧", for: .normal)
        } else {
            row3.keys.first?.setTitle("⇪", for: .normal)
        }
        for row in [row1, row2, row3] {
            for key in row.keys where key.style == .character {
                let uppercase = state != .off
                let title = uppercase
                    ? key.keyValue.uppercased(with: Locale(identifier: definition.localeIdentifier))
                    : key.keyValue
                key.setTitle(title, for: .normal)
            }
        }
        applyAppearance()
    }

    private func updateShiftForContext() {
        guard KeyboardPreferences.autoCapitalize, page == .letters else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let sentenceStart = before.isEmpty
            || before.hasSuffix(". ")
            || before.hasSuffix("\n")
            || before.hasSuffix("? ")
            || before.hasSuffix("! ")
        if sentenceStart, shift == .off { setShift(.once) }
    }

    private func feedback() {
        if KeyboardPreferences.haptics {
            impact.prepare()
            impact.impactOccurred()
        }
        if KeyboardPreferences.sounds {
            AudioServicesPlaySystemSound(1104)
        }
    }

    // MARK: - Appearance

    private func applyAppearance() {
        let dark: Bool = {
            switch appearance {
            case .dark: return true
            case .light: return false
            case .system: return traitCollection.userInterfaceStyle == .dark
            }
        }()
        view.backgroundColor = dark ? UIColor(white: 0.11, alpha: 1) : UIColor(white: 0.83, alpha: 1)
        settingsPanel.backgroundColor = view.backgroundColor
        settingsButton.tintColor = dark ? .white : .darkGray
        statusLabel.textColor = dark ? UIColor(white: 0.75, alpha: 1) : .darkGray
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard appearance == .system,
              previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        for row in [row1, row2, row3, row4] {
            row.keys.forEach { $0.applyColors() }
        }
        applyAppearance()
    }

    // MARK: - Settings panel

    private func buildSettingsPanel() {
        settingsPanel.backgroundColor = view.backgroundColor
        settingsPanel.isHidden = true
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsPanel)
        NSLayoutConstraint.activate([
            settingsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsPanel.topAnchor.constraint(equalTo: view.topAnchor),
            settingsPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func toggleSettings() {
        if !settingsPanel.isHidden {
            settingsPanel.isHidden = true
            return
        }
        settingsPanel.subviews.forEach { $0.removeFromSuperview() }

        let title = UILabel()
        title.text = "Keyboard settings"
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        done.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, UIView(), done])

        let layoutControl = UISegmentedControl(items: KeyboardLayoutID.allCases.map(\.shortName))
        layoutControl.selectedSegmentIndex = KeyboardLayoutID.allCases.firstIndex(of: layoutID) ?? 0
        layoutControl.addTarget(self, action: #selector(layoutChanged(_:)), for: .valueChanged)

        let layoutRow = UIStackView(arrangedSubviews: [UILabel.makeCaption("Layout"), UIView(), layoutControl])

        let haptics = UISwitch()
        haptics.isOn = KeyboardPreferences.haptics
        haptics.addTarget(self, action: #selector(toggleHaptics(_:)), for: .valueChanged)
        let sounds = UISwitch()
        sounds.isOn = KeyboardPreferences.sounds
        sounds.addTarget(self, action: #selector(toggleSounds(_:)), for: .valueChanged)
        let autoCap = UISwitch()
        autoCap.isOn = KeyboardPreferences.autoCapitalize
        autoCap.addTarget(self, action: #selector(toggleAutoCap(_:)), for: .valueChanged)

        let appearanceControl = UISegmentedControl(items: KeyboardAppearanceID.allCases.map { $0.displayName })
        appearanceControl.selectedSegmentIndex = KeyboardAppearanceID.allCases.firstIndex(of: appearance) ?? 0
        appearanceControl.addTarget(self, action: #selector(appearanceChanged(_:)), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [
            header,
            layoutRow,
            makeSettingRow("Haptics", haptics),
            makeSettingRow("Key sounds", sounds),
            makeSettingRow("Auto-capitalise", autoCap),
            UIStackView(arrangedSubviews: [UILabel.makeCaption("Appearance"), appearanceControl])
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(14, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: settingsPanel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: settingsPanel.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: settingsPanel.topAnchor, constant: 12)
        ])
        settingsPanel.isHidden = false
    }

    private func makeSettingRow(_ label: String, _ control: UISwitch) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [UILabel.makeCaption(label), UIView(), control])
        row.alignment = .center
        return row
    }

    @objc private func layoutChanged(_ sender: UISegmentedControl) {
        layoutID = KeyboardLayoutID.allCases[sender.selectedSegmentIndex]
        KeyboardPreferences.layout = layoutID
        definition = KeyboardLayoutDefinition.definition(for: layoutID)
        page = .letters
        buildKeys()
        setShift(shift)
    }

    @objc private func appearanceChanged(_ sender: UISegmentedControl) {
        appearance = KeyboardAppearanceID.allCases[sender.selectedSegmentIndex]
        KeyboardPreferences.appearance = appearance
        overrideUserInterfaceStyle = appearance.interfaceStyle
        applyAppearance()
        settingsPanel.backgroundColor = view.backgroundColor
        row1.keys.forEach { $0.applyColors() }
        row2.keys.forEach { $0.applyColors() }
        row3.keys.forEach { $0.applyColors() }
        row4.keys.forEach { $0.applyColors() }
    }

    @objc private func toggleHaptics(_ sender: UISwitch) { KeyboardPreferences.haptics = sender.isOn }
    @objc private func toggleSounds(_ sender: UISwitch) { KeyboardPreferences.sounds = sender.isOn }
    @objc private func toggleAutoCap(_ sender: UISwitch) { KeyboardPreferences.autoCapitalize = sender.isOn }

    // MARK: - Dictation

    private func configureDictation() {
        capture.onReady = { [weak self] in self?.setStatus("Dictate ready") }
        capture.onStarted = { [weak self] in
            guard let self else { return }
            self.setStatus(self.usingOnDevice ? "Listening on device…" : "Listening (network)…")
        }
        capture.onAudio = { [weak self] data, rms in self?.append(data, rms: rms) }
        capture.onEnded = { [weak self] reason in self?.captureEnded(reason) }
        capture.attach(to: view)
    }

    @objc private func toggleDictation() {
        capture.isCapturing ? stopDictation() : startDictation()
    }

    private func startDictation() {
        guard hasFullAccess else {
            return setStatus("Enable Allow Full Access for this keyboard.")
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            return setStatus("Grant microphone access in the dict8 app.")
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            return setStatus("Grant speech recognition in the dict8 app.")
        }
        let language = definition.localeIdentifier
        let speech = SFSpeechRecognizer(locale: Locale(identifier: language))
        guard let speech, speech.isAvailable else {
            return setStatus("Speech recognition unavailable for \(language).")
        }
        recognizer = speech
        speechRecognizer = speech
        didFallBackToNetwork = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if speech.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            usingOnDevice = true
        } else {
            usingOnDevice = false
        }
        self.request = request
        insertedPartial = ""
        capturedSamples = 0
        speechError = nil

        task = speech.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async { self?.handle(result: result, error: error) }
        }
        capture.start()
        setStatus("Starting microphone…")
        micKey?.isRecording = true
        refreshMicKeys()
    }

    private func stopDictation() {
        capture.stop()
    }

    private func captureEnded(_ reason: String) {
        log.info("capture ended: \(reason, privacy: .private)")
        request?.endAudio()
        if reason == "stopped" {
            setStatus(insertedPartial.isEmpty ? "Done" : "Inserted")
        } else {
            setStatus(reason)
        }
        micKey?.isRecording = false
        refreshMicKeys()
    }

    private func refreshMicKeys() {
        micKey?.isRecording = capture.isCapturing
        micKey?.applyColors()
    }

    private func append(_ data: Data, rms: Float) {
        let frames = AVAudioFrameCount(data.count / 2)
        guard frames > 0 else { return }
        capturedSamples += Int(frames)
        let seconds = Double(capturedSamples) / WebAudioCapture.sampleRate
        let bars = String(repeating: "▮", count: min(Int(rms * 60), 8))
        setStatus(String(format: "Listening %.1fs %@", seconds, bars))

        guard let request, let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        data.withUnsafeBytes { raw in
            buffer.int16ChannelData![0].update(from: raw.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        request.append(buffer)
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            replacePartial(with: result.bestTranscription.formattedString)
            if result.isFinal {
                capture.stop()
                finishRecognition(status: "Inserted")
            }
        } else if let error {
            log.error("recognition error: \(error.localizedDescription, privacy: .private)")
            if capture.isCapturing, usingOnDevice, !didFallBackToNetwork, let speechRecognizer {
                // On-device model missing or failed: keep the same microphone stream and retry online.
                didFallBackToNetwork = true
                usingOnDevice = false
                let fallback = SFSpeechAudioBufferRecognitionRequest()
                fallback.shouldReportPartialResults = true
                fallback.addsPunctuation = true
                request = fallback
                task = speechRecognizer.recognitionTask(with: fallback) { [weak self] result, error in
                    DispatchQueue.main.async { self?.handle(result: result, error: error) }
                }
                setStatus("Switched to network recognition")
                return
            }
            if capture.isCapturing {
                speechError = error.localizedDescription
                task = nil
                request = nil
            } else {
                finishRecognition(status: speechError.map { "Speech: \($0)" } ?? "Done")
            }
        }
    }

    private func replacePartial(with text: String) {
        guard text != insertedPartial else { return }
        let common = zip(insertedPartial, text).prefix { $0 == $1 }.count
        for _ in 0..<(insertedPartial.count - common) { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(String(text.dropFirst(common)))
        insertedPartial = text
    }

    private func finishRecognition(status: String) {
        task = nil
        request = nil
        insertedPartial = ""
        setStatus(status)
        micKey?.isRecording = false
        refreshMicKeys()
    }

    private func setStatus(_ text: String) {
        statusLabel.text = text
    }
}

private extension UILabel {
    static func makeCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }
}
