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
    /// True when shift was switched on by auto-capitalisation rather than by a tap.
    private var shiftIsAuto = false
    private var lastShiftTap = Date.distantPast
    private var layoutID: KeyboardLayoutID = .qwerty
    private var definition = KeyboardLayoutDefinition.definition(for: .qwerty)
    private var theme = KeyboardTheme.dark
    private var metrics = KeyboardMetrics.portrait
    private var heightConstraint: NSLayoutConstraint?
    private let impact = UIImpactFeedbackGenerator(style: .light)

    private let engine = SuggestionEngine()
    private let personal = PersonalModel()
    /// The letters of the word being typed, with where each tap landed.
    private var typedLetters: [TypedLetter] = []
    /// The latest finished analysis; only used if it is for the word under the cursor.
    private var analysis: SuggestionEngine.WordAnalysis?
    /// The last automatic correction, so one backspace can take it back.
    private var lastAutocorrect: (typed: String, corrected: String, trailer: String)?
    private var cachedGeometry: KeyGeometry?
    /// Text replacements from iOS Settings: lowercased shortcut → what it expands to.
    private var shortcuts: [String: String] = [:]
    /// Contact names and other words iOS knows, which are never corrected.
    private var lexiconWords: Set<String> = []
    private let keyPreview = KeyPreviewView()
    /// Dictionary lookups take tens of milliseconds, so they never run on the main thread.
    private let suggestionQueue = DispatchQueue(label: "com.kazo.voicekeyboard.suggestions", qos: .userInitiated)
    private var suggestionWork: DispatchWorkItem?
    private var suggestionKey: String?
    private var shownReturnLabel: String?
    private var builtLayout: KeyboardLayoutID?
    private var currentSuggestions: [String] = []
    /// A space added after a tapped suggestion; removed again if punctuation follows.
    private var pendingAutoSpace = false
    /// Non-nil while the keys type into the emoji search instead of the document.
    private var searchQuery: String?
    private var showsEmoji = false
    private var trackpadX: CGFloat = 0
    private var polishTask: Task<Void, Never>?

    // MARK: - Views

    private let topBar = TopBarView()
    private let pillRow = ActionPillRow()
    private let resultStrip = EmojiResultStrip()
    private let rows = (0..<4).map { _ in KeyRowView() }
    private let emojiPanel = EmojiPanelView()
    private let settingsPanel = UIView()

    // MARK: - Dictation

    private let capture = WebAudioCapture()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: WebAudioCapture.sampleRate, channels: 1, interleaved: true
    )!
    /// Text typed so far for the utterance the recogniser is still revising.
    private var insertedPartial = ""
    /// Earlier utterances are final: they stay in the document and are never retyped.
    private var committedUtterances = 0
    private var lastCommitted = ""
    /// What the document actually holds for each committed utterance, newest last.
    private var committedShown: [String] = []
    private var dictationLanguage = "en_US"
    private var dictationVocabulary: [String] = []
    private var levelTick = 0
    private var capturedSamples = 0
    private var speechError: String?
    private var usingOnDevice = false
    private var speechRecognizer: SFSpeechRecognizer?
    private var didSwitchMode = false
    private var recognizers: [String: SFSpeechRecognizer] = [:]
    /// Callbacks from a recognition task that has been replaced are ignored.
    private var taskGeneration = 0
    private var taskStartedAt = Date.distantPast

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
        configureHierarchy()
        configureDictation()
        buildKeys()
        refreshSuggestions()
        loadLexicon()
    }

    /// iOS hands keyboards the person's text replacements and contact names.
    private func loadLexicon() {
        requestSupplementaryLexicon { [weak self] lexicon in
            var shortcuts: [String: String] = [:]
            var words = Set<String>()
            for entry in lexicon.entries {
                let typed = entry.userInput.lowercased()
                if typed != entry.documentText.lowercased(), !typed.contains(" ") {
                    shortcuts[typed] = entry.documentText
                } else {
                    entry.documentText.lowercased().split(separator: " ").forEach { words.insert(String($0)) }
                }
            }
            DispatchQueue.main.async {
                self?.shortcuts = shortcuts
                self?.lexiconWords = words
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPreferences()
        personal.reload()
        showsEmoji = false
        searchQuery = nil
        topBar.setSearch(nil)
        // viewDidLoad already built the keys; only rebuild if something changed.
        if page != .letters || builtLayout != layoutID {
            page = .letters
            buildKeys()
        }
        updateVisibility()
        updateShiftForContext()
        refreshSuggestions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        polishTask?.cancel()
        personal.save()
        if capture.isCapturing { stopDictation() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutContent()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Dictation rewrites the text many times a second; nothing here needs to follow it.
        guard !isDictating else { return }
        applyTheme()
        updateReturnKey()
        updateShiftForContext()
        refreshSuggestions()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func loadPreferences() {
        layoutID = KeyboardPreferences.layout
        definition = KeyboardLayoutDefinition.definition(for: layoutID)
    }

    // MARK: - View setup

    private func configureHierarchy() {
        // No background of our own: the system keyboard backdrop shows through.
        view.backgroundColor = .clear

        // The keyboard sizes itself around this invisible view; a height constraint
        // on the input view alone is overridden by the system's default height.
        inputView?.allowsSelfSizing = true
        let sizer = UIView()
        sizer.isUserInteractionEnabled = false
        sizer.isHidden = true
        sizer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sizer)
        let height = sizer.heightAnchor.constraint(equalToConstant: metrics.height)
        height.priority = .init(999)
        heightConstraint = height
        NSLayoutConstraint.activate([
            sizer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sizer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sizer.topAnchor.constraint(equalTo: view.topAnchor),
            sizer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height
        ])

        topBar.onMenu = { [weak self] in self?.toggleSettings() }
        topBar.onVoice = { [weak self] in
            self?.feedback()
            self?.toggleDictation()
        }
        topBar.onSuggestion = { [weak self] index in self?.acceptSuggestion(at: index) }
        pillRow.onAction = { [weak self] action in self?.perform(action) }
        // Tap polishes; holding the pill offers other rewrites.
        pillRow.setPolishMenu(UIMenu(children: TextPolisher.Style.allCases.map { style in
            UIAction(title: style.title, image: UIImage(systemName: style.symbol)) { [weak self] _ in
                self?.feedback()
                self?.polish(style)
            }
        }))
        resultStrip.onEmoji = { [weak self] emoji in self?.insertEmoji(emoji) }
        resultStrip.onClose = { [weak self] in self?.endSearch() }
        emojiPanel.onEmoji = { [weak self] emoji in self?.insertEmoji(emoji) }
        emojiPanel.onDelete = { [weak self] in
            self?.feedback()
            self?.textDocumentProxy.deleteBackward()
        }
        emojiPanel.onClose = { [weak self] in self?.setEmojiVisible(false) }

        view.addSubview(topBar)
        view.addSubview(pillRow)
        view.addSubview(resultStrip)
        rows.forEach { view.addSubview($0) }
        view.addSubview(emojiPanel)

        keyPreview.isHidden = true
        view.addSubview(keyPreview)

        settingsPanel.isHidden = true
        view.addSubview(settingsPanel)
        updateVisibility()
    }

    private func layoutContent() {
        // Landscape is judged by width: the keyboard is always wider than it is tall.
        let next: KeyboardMetrics = view.bounds.width > 600 ? .landscape : .portrait
        if heightConstraint?.constant != next.height { heightConstraint?.constant = next.height }
        let orientationChanged = next.showsPills != metrics.showsPills
        metrics = next
        if orientationChanged, searchQuery != nil { endSearch() }

        let width = view.bounds.width
        topBar.frame = CGRect(x: 0, y: metrics.topBarY, width: width, height: metrics.topBarHeight)
        pillRow.frame = CGRect(x: 0, y: metrics.pillY, width: width, height: metrics.pillHeight)
        resultStrip.frame = pillRow.frame
        for (index, row) in rows.enumerated() {
            row.rowGap = metrics.rowGap
            row.frame = CGRect(
                x: 0, y: metrics.keysY + metrics.rowPitch * CGFloat(index), width: width, height: metrics.rowPitch
            )
        }
        let panelTop = metrics.showsPills ? metrics.pillY : metrics.keysY
        emojiPanel.frame = CGRect(x: 0, y: panelTop, width: width, height: max(view.bounds.height - panelTop, 0))
        settingsPanel.frame = view.bounds
        cachedGeometry = nil
        updateVisibility()
    }

    private func updateVisibility() {
        let searching = searchQuery != nil
        pillRow.isHidden = !metrics.showsPills || searching || showsEmoji
        resultStrip.isHidden = !metrics.showsPills || !searching || showsEmoji
        rows.forEach { $0.isHidden = showsEmoji }
        emojiPanel.isHidden = !showsEmoji
    }

    // MARK: - Key rows

    private func buildKeys() {
        switch page {
        case .letters:
            let layout = definition.rows
            rows[0].setItems(layout[0].map { .key(makeKey($0), .unit(1)) })
            rows[1].setItems([.gap] + layout[1].map { .key(makeKey($0), .unit(1)) } + [.gap])
            rows[2].setItems(sideKeyRow(layout[2], middleUnit: 1))
        case .numbers:
            rows[0].setItems(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { .key(makeKey($0), .unit(1)) })
            rows[1].setItems(["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""].map { .key(makeKey($0), .unit(1)) })
            rows[2].setItems(sideKeyRow(["#+=", ".", ",", "?", "!", "'", "⌫"], middleUnit: 1.42))
        case .symbols:
            rows[0].setItems(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { .key(makeKey($0), .unit(1)) })
            rows[1].setItems(["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"].map { .key(makeKey($0), .unit(1)) })
            rows[2].setItems(sideKeyRow(["123", ".", ",", "?", "!", "'", "⌫"], middleUnit: 1.42))
        }

        var bottom: [KeyRowView.Item] = [
            .key(makeKey(page == .letters ? "123" : "ABC"), .unit(1.35)),
            .key(makeKey("emoji"), .unit(1.35))
        ]
        // Face ID phones get the globe from the system, below the keyboard.
        if needsInputModeSwitchKey { bottom.append(.key(makeKey("🌐"), .unit(1.35))) }
        bottom.append(.key(makeKey("space"), .flex))
        bottom.append(.key(makeKey("return"), .unit(2.75)))
        rows[3].setItems(bottom)

        builtLayout = layoutID
        shownReturnLabel = nil
        cachedGeometry = nil
        applyTheme()
        applyShiftAppearance()
        updateReturnKey()
    }

    /// A row with a wide key at each end and the rest centred between them.
    private func sideKeyRow(_ values: [String], middleUnit: CGFloat) -> [KeyRowView.Item] {
        guard values.count > 2, let first = values.first, let last = values.last else { return [] }
        var items: [KeyRowView.Item] = [.key(makeKey(first), .unit(1.35)), .gap]
        items += values.dropFirst().dropLast().map { .key(makeKey($0), .unit(middleUnit)) }
        items += [.gap, .key(makeKey(last), .unit(1.35))]
        return items
    }

    private func makeKey(_ value: String) -> KeyButton {
        let key = KeyButton()
        key.keyValue = value
        key.theme = theme
        key.onTap = { [weak self] tapped in self?.handleTap(tapped) }

        switch value {
        case "⇧":
            key.style = .shift
            key.accessibilityLabel = "Shift"
        case "⌫":
            key.style = .delete
            key.setSymbol("delete.left", pointSize: 20)
            key.accessibilityLabel = "Delete"
            key.repeatAction = { [weak self] count in
                guard let self else { return }
                // After a couple of seconds, speed up to whole words like the system keyboard.
                if count > 20 { self.deleteWord() } else { self.deleteOne() }
            }
        case "space":
            key.style = .space
            key.setLabel("", size: 16)
            key.accessibilityLabel = "Space"
            let press = UILongPressGestureRecognizer(target: self, action: #selector(handleSpaceTrackpad(_:)))
            press.minimumPressDuration = 0.35
            key.addGestureRecognizer(press)
        case "return":
            key.style = .special
        case "emoji":
            key.style = .special
            key.setSymbol("face.smiling.fill", pointSize: 21)
            key.accessibilityLabel = "Emoji"
        case "🌐":
            key.style = .special
            key.setSymbol("globe", pointSize: 19)
            key.accessibilityLabel = "Next keyboard"
            key.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        case "123", "ABC", "#+=":
            key.style = .special
            key.setLabel(value, size: 16)
        default:
            key.style = .character
            key.setLabel(value)
            key.onPress = { [weak self] pressed, down in self?.showPreview(for: pressed, visible: down) }
            if let accents = definition.accents[value.lowercased()], !accents.isEmpty {
                key.menu = accentMenu(base: value, accents: accents)
                key.showsMenuAsPrimaryAction = false
            }
        }
        return key
    }

    private var returnKeyLabel: String {
        switch textDocumentProxy.returnKeyType {
        case .go: return "go"
        case .google, .search, .yahoo: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .emergencyCall: return "call"
        case .continue: return "continue"
        default: return "return"
        }
    }

    private func updateReturnKey() {
        guard let key = rows[3].keys.last, key.keyValue == "return" else { return }
        let label = returnKeyLabel
        guard label != shownReturnLabel else { return }
        shownReturnLabel = label
        if label == "return" {
            key.setSymbol("return", pointSize: 19, weight: .medium)
        } else {
            key.setLabel(label, size: 16)
        }
        key.accessibilityLabel = label
    }

    private func accentMenu(base: String, accents: [String]) -> UIMenu {
        let actions = accents.map { accent in
            UIAction(title: accent) { [weak self] _ in
                guard let self else { return }
                self.feedback()
                self.insertCharacter(accent)
            }
        }
        return UIMenu(title: base, children: actions)
    }

    // MARK: - Tap handling

    private func handleTap(_ key: KeyButton) {
        feedback()
        switch key.keyValue {
        case "⇧":
            let now = Date()
            if shift == .caps {
                setShift(.off)
            } else if now.timeIntervalSince(lastShiftTap) < 0.35 {
                setShift(.caps)
            } else {
                setShift(shift == .off ? .once : .off)
            }
            lastShiftTap = now
        case "⌫":
            deleteOne()
        case "🌐":
            break // handled by the input mode target
        case "emoji":
            setEmojiVisible(true)
        case "space":
            insertSpace()
        case "return":
            if searchQuery != nil { endSearch() } else { insertRaw("\n") }
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
            let point = key.lastTouchPoint.map { key.convert($0, to: view) }
            insertCharacter(resolvedValue(for: key, at: point), tap: point)
        }
    }

    /// The enlarged letter that pops up over a key while it is held.
    private func showPreview(for key: KeyButton, visible: Bool) {
        guard visible, KeyboardPreferences.keyPopups, let title = key.title(for: .normal), !title.isEmpty else {
            keyPreview.isHidden = true
            return
        }
        let frame = key.convert(key.bounds, to: view)
        let width = max(frame.width + 14, 46)
        let x = min(max(frame.midX - width / 2, 2), view.bounds.width - width - 2)
        keyPreview.frame = CGRect(x: x, y: max(frame.minY - 50, 0), width: width, height: 54)
        keyPreview.show(title)
        view.bringSubviewToFront(keyPreview)
        if !settingsPanel.isHidden { view.bringSubviewToFront(settingsPanel) }
    }

    /// The letter a tap most likely meant. Once the keyboard has learned where this
    /// person's taps land for a key, a tap near the edge goes to the key they were aiming at.
    private func resolvedValue(for key: KeyButton, at point: CGPoint?) -> String {
        guard page == .letters, key.style == .character, let point, let row = key.superview as? KeyRowView,
              let index = row.keys.firstIndex(of: key) else { return key.keyValue }
        var best = key
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for candidate in row.keys[max(index - 1, 0)...min(index + 1, row.keys.count - 1)]
        where candidate.style == .character {
            guard let letter = candidate.keyValue.first else { continue }
            let offset = personal.data.offset(for: letter)
            let centre = candidate.convert(CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY), to: view)
            let dx = point.x - centre.x - offset.x * (candidate.bounds.width + row.spacing)
            let dy = point.y - centre.y - offset.y * row.bounds.height
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best.keyValue
    }

    /// Key centres for the letters page, used to judge how likely a slip was.
    private func keyGeometry() -> KeyGeometry {
        if let cachedGeometry { return cachedGeometry }
        var geometry = KeyGeometry()
        geometry.keyHeight = metrics.rowPitch
        guard page == .letters else { return geometry }
        for row in rows.prefix(3) {
            for key in row.keys where key.style == .character {
                guard let letter = key.keyValue.first, key.keyValue.count == 1 else { continue }
                geometry.centers[letter] = key.convert(CGPoint(x: key.bounds.midX, y: key.bounds.midY), to: view)
                geometry.keyWidth = key.bounds.width + row.spacing
            }
        }
        if !geometry.centers.isEmpty, geometry.keyWidth > 10 { cachedGeometry = geometry }
        return geometry
    }

    private func insertCharacter(_ text: String, tap: CGPoint? = nil) {
        var output = text
        if page == .letters, shift != .off {
            output = text.uppercased(with: Locale(identifier: definition.localeIdentifier))
        }
        if let query = searchQuery {
            searchQuery = query + output.lowercased()
            if shift == .once { setShift(.off) }
            return updateSearch()
        }
        lastAutocorrect = nil
        if output.count == 1, let character = output.first, character.isLetter || character == "'" {
            typedLetters.append(TypedLetter(character: character, point: tap))
        } else {
            // Punctuation finishes the word just like a space does.
            finishWord(trailer: output)
        }
        // "word " + "." reads better as "word." when the space came from a suggestion.
        if pendingAutoSpace, output.count == 1, ".,?!:;".contains(output),
           textDocumentProxy.documentContextBeforeInput?.hasSuffix(" ") == true {
            textDocumentProxy.deleteBackward()
        }
        insertRaw(output)
    }

    private func insertRaw(_ text: String) {
        pendingAutoSpace = false
        textDocumentProxy.insertText(text)
        if shift == .once { setShift(.off) }
        afterTextChange()
    }

    private func insertSpace() {
        if let query = searchQuery {
            searchQuery = query + " "
            return updateSearch()
        }
        lastAutocorrect = nil
        finishWord(trailer: " ")
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let previous = before.dropLast().last
        if before.hasSuffix(" "), let previous, previous.isLetter || previous.isNumber {
            // Double space types a full stop.
            textDocumentProxy.deleteBackward()
            insertRaw(". ")
        } else {
            insertRaw(" ")
        }
        if page != .letters {
            page = .letters
            buildKeys()
        }
    }

    private func deleteOne() {
        if let query = searchQuery {
            searchQuery = String(query.dropLast())
            return updateSearch()
        }
        pendingAutoSpace = false
        // Straight after an autocorrection, backspace puts back what was typed and
        // remembers not to change that word again.
        if let last = lastAutocorrect {
            lastAutocorrect = nil
            let applied = last.corrected + last.trailer
            if (textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(applied) {
                for _ in applied { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(last.typed + last.trailer)
                personal.update { $0.keep(last.typed) }
                typedLetters = []
                topBar.flashStatus("Kept “\(last.typed)”", seconds: 1.5)
                return afterTextChange()
            }
        }
        if !typedLetters.isEmpty { typedLetters.removeLast() }
        textDocumentProxy.deleteBackward()
        afterTextChange()
    }

    // MARK: - Autocorrect

    /// Autocorrect and learning stay out of fields that ask for neither, such as web addresses.
    private var fieldAllowsCorrection: Bool {
        if textDocumentProxy.autocorrectionType == .no { return false }
        switch textDocumentProxy.keyboardType ?? .default {
        case .URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .numbersAndPunctuation, .webSearch:
            return false
        default:
            return true
        }
    }

    /// The tap record for `word`, or plain letters if it was not typed key by key.
    private func letters(for word: String) -> [TypedLetter] {
        String(typedLetters.map(\.character)) == word
            ? typedLetters : word.map { TypedLetter(character: $0, point: nil) }
    }

    /// Called when a space or punctuation ends a word, before that character is typed.
    private func finishWord(trailer: String) {
        defer { typedLetters = [] }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let word = SuggestionEngine.partialWord(in: context)
        guard !word.isEmpty, fieldAllowsCorrection else { return }
        let typed = letters(for: word)
        let previous = SuggestionEngine.previousWord(before: word, in: context)
        if let analysis, analysis.word == word {
            settle(analysis, letters: typed, previous: previous, trailer: trailer, afterTheFact: false)
            return
        }
        // Typed faster than the lookup: finish it in the background and fix the word up after.
        let lookup = makeAnalysis(context: String(context.suffix(48)), letters: typed)
        suggestionQueue.async { [weak self] in
            let result = lookup()
            DispatchQueue.main.async {
                self?.settle(result, letters: typed, previous: previous, trailer: trailer, afterTheFact: true)
            }
        }
    }

    /// Applies the correction for a finished word, or learns the word if it stands.
    private func settle(
        _ result: SuggestionEngine.WordAnalysis, letters: [TypedLetter], previous: String?,
        trailer: String, afterTheFact: Bool
    ) {
        let geometry = keyGeometry()
        guard let correction = result.correction, KeyboardPreferences.autoCorrect else {
            personal.update { model in
                model.noteWord(result.word, knownToDictionary: result.known)
                if let previous { model.notePair(previous, result.word) }
                if result.known { Self.learnTaps(letters, meant: result.word, geometry: geometry, into: &model) }
            }
            return
        }
        if afterTheFact {
            // Only if nothing else has been typed since.
            let typed = result.word + trailer
            guard (textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(typed) else { return }
            for _ in typed { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(correction + trailer)
        } else {
            for _ in result.word { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(correction)
        }
        lastAutocorrect = (result.word, correction, trailer)
        personal.update { model in
            model.noteWord(correction, knownToDictionary: true)
            if let previous, !correction.contains(" ") { model.notePair(previous, correction) }
            Self.learnTaps(letters, meant: correction, geometry: geometry, into: &model)
        }
    }

    /// Records where each tap landed relative to the key it turned out to be meant for.
    private static func learnTaps(
        _ letters: [TypedLetter], meant word: String, geometry: KeyGeometry, into model: inout PersonalModelData
    ) {
        let meant = Array(word.lowercased())
        guard meant.count == letters.count, geometry.keyWidth > 0, geometry.keyHeight > 0 else { return }
        for (letter, target) in zip(letters, meant) {
            guard let point = letter.point, let centre = geometry.centers[target] else { continue }
            model.noteTap(
                for: target,
                dx: Double((point.x - centre.x) / geometry.keyWidth),
                dy: Double((point.y - centre.y) / geometry.keyHeight)
            )
        }
    }

    /// Packages a lookup with copies of everything it needs, to run off the main thread.
    private func makeAnalysis(context: String, letters: [TypedLetter]) -> () -> SuggestionEngine.WordAnalysis {
        let engine = engine
        let locale = definition.localeIdentifier
        let geometry = keyGeometry()
        let model = personal.data
        let autocorrect = KeyboardPreferences.autoCorrect && fieldAllowsCorrection
        let shortcuts = shortcuts
        let names = lexiconWords
        return {
            engine.analyse(
                context: context, letters: letters, locale: locale, geometry: geometry,
                model: model, autocorrect: autocorrect, shortcuts: shortcuts, names: names
            )
        }
    }

    private func deleteWord() {
        guard searchQuery == nil else { return deleteOne() }
        typedLetters = []
        lastAutocorrect = nil
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var count = 0
        var seenWord = false
        for character in before.reversed() {
            if character.isWhitespace {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += 1
        }
        for _ in 0..<max(count, 1) { textDocumentProxy.deleteBackward() }
        afterTextChange()
    }

    private func afterTextChange() {
        updateShiftForContext()
        refreshSuggestions()
    }

    /// Replaces the text before the cursor, retyping only the part that changed.
    private func replaceContext(_ old: String, with new: String) {
        let common = zip(old, new).prefix { $0 == $1 }.count
        for _ in 0..<(old.count - common) { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(String(new.dropFirst(common)))
        afterTextChange()
    }

    // MARK: - Space bar trackpad

    @objc private func handleSpaceTrackpad(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            trackpadX = gesture.location(in: view).x
            feedback()
            UIView.animate(withDuration: 0.15) { self.rows.forEach { $0.alpha = 0.45 } }
        case .changed:
            let x = gesture.location(in: view).x
            let steps = Int((x - trackpadX) / 9)
            guard steps != 0 else { return }
            textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
            trackpadX += CGFloat(steps) * 9
        default:
            UIView.animate(withDuration: 0.15) { self.rows.forEach { $0.alpha = 1 } }
            afterTextChange()
        }
    }

    // MARK: - Shift

    private func setShift(_ state: ShiftState, auto: Bool = false) {
        shift = state
        shiftIsAuto = auto
        applyShiftAppearance()
    }

    private func applyShiftAppearance() {
        guard page == .letters else { return }
        let locale = Locale(identifier: definition.localeIdentifier)
        for row in rows.prefix(3) {
            for key in row.keys {
                switch key.style {
                case .character:
                    key.setLabel(shift == .off ? key.keyValue : key.keyValue.uppercased(with: locale))
                case .shift:
                    switch shift {
                    case .off: key.setSymbol("shift", pointSize: 19, weight: .medium)
                    case .once: key.setSymbol("shift.fill", pointSize: 19, weight: .medium)
                    case .caps: key.setSymbol("capslock.fill", pointSize: 19, weight: .medium)
                    }
                default:
                    break
                }
            }
        }
    }

    private func updateShiftForContext() {
        guard KeyboardPreferences.autoCapitalize, page == .letters, shift != .caps, searchQuery == nil else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let wantsCapital: Bool
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none:
            wantsCapital = false
        case .allCharacters:
            wantsCapital = true
        case .words:
            wantsCapital = before.isEmpty || before.last?.isWhitespace == true
        default:
            wantsCapital = before.isEmpty || before.hasSuffix(". ") || before.hasSuffix("? ")
                || before.hasSuffix("! ") || before.hasSuffix("\n")
        }
        if wantsCapital, shift == .off {
            setShift(.once, auto: true)
        } else if !wantsCapital, shift == .once, shiftIsAuto {
            setShift(.off)
        }
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

    // MARK: - Suggestions

    private var isDictating: Bool { capture.isCapturing || task != nil }

    private func refreshSuggestions() {
        guard !isDictating, searchQuery == nil, !showsEmoji else { return }
        // Only the end of the text decides the suggestions.
        let context = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(48))
        let locale = definition.localeIdentifier
        let key = locale + "|" + context
        guard key != suggestionKey else { return }
        suggestionKey = key

        suggestionWork?.cancel()
        let lookup = makeAnalysis(context: context, letters: letters(for: SuggestionEngine.partialWord(in: context)))
        var work: DispatchWorkItem!
        work = DispatchWorkItem { [weak self] in
            let result = lookup()
            DispatchQueue.main.async {
                guard let self, self.suggestionKey == key else { return }
                self.analysis = result
                self.currentSuggestions = result.suggestions
                self.topBar.setSuggestions(result.suggestions, emphasised: result.correction == nil ? nil : 1)
            }
        }
        suggestionWork = work
        suggestionQueue.async(execute: work)
    }

    private func acceptSuggestion(at index: Int) {
        guard index < currentSuggestions.count else { return }
        feedback()
        // The first slot quotes the word exactly as typed; choosing it means "leave this alone".
        let asTyped = currentSuggestions[index].hasPrefix("“")
        let word = currentSuggestions[index].trimmingCharacters(in: CharacterSet(charactersIn: "“”"))
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        if fieldAllowsCorrection {
            let partial = SuggestionEngine.partialWord(in: context)
            let previous = SuggestionEngine.previousWord(before: partial, in: context)
            personal.update { model in
                if asTyped { model.keep(word) } else { model.noteWord(word, knownToDictionary: true) }
                if let previous { model.notePair(previous, word) }
            }
        }
        typedLetters = []
        lastAutocorrect = nil
        for _ in SuggestionEngine.partialWord(in: context) { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(word + " ")
        pendingAutoSpace = true
        if shift == .once { setShift(.off) }
        afterTextChange()
    }

    // MARK: - Pill actions

    private func perform(_ action: ActionPillRow.Action) {
        feedback()
        switch action {
        case .proofread: proofread()
        case .paste: paste()
        case .search: beginSearch()
        case .polish: polish(.polish)
        }
    }

    private func proofread() {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return topBar.flashStatus("Nothing to check yet")
        }
        let result = engine.proofread(context, locale: definition.localeIdentifier)
        guard result.fixes > 0, result.text != context else { return topBar.flashStatus("Looks good") }
        replaceContext(context, with: result.text)
        topBar.flashStatus(result.fixes == 1 ? "Fixed 1 thing" : "Fixed \(result.fixes) things")
    }

    private func paste() {
        guard hasFullAccess else { return topBar.flashStatus("Paste needs Allow Full Access") }
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            return topBar.flashStatus("Clipboard has no text")
        }
        insertRaw(text)
    }

    private func polish(_ style: TextPolisher.Style) {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return topBar.flashStatus("Write something to polish first")
        }
        pillRow.setBusy(true, action: .polish)
        topBar.flashStatus("Polishing…", seconds: 30)
        polishTask?.cancel()
        polishTask = Task { [weak self] in
            let outcome: Result<String, Error>
            do { outcome = .success(try await TextPolisher.polish(context, style: style)) } catch { outcome = .failure(error) }
            guard let self, !Task.isCancelled else { return }
            self.pillRow.setBusy(false, action: .polish)
            switch outcome {
            case let .success(polished):
                // The user may have kept typing while the model worked.
                guard self.textDocumentProxy.documentContextBeforeInput == context else {
                    return self.topBar.flashStatus("Text changed, polish skipped")
                }
                guard polished != context else { return self.topBar.flashStatus("Already reads well") }
                self.replaceContext(context, with: polished)
                self.topBar.flashStatus("Polished")
            case let .failure(error):
                log.error("polish failed: \(error.localizedDescription, privacy: .private)")
                self.topBar.flashStatus(error.localizedDescription, seconds: 3.5)
            }
        }
    }

    // MARK: - Emoji

    private func setEmojiVisible(_ visible: Bool) {
        if visible {
            if searchQuery != nil { endSearch() }
            emojiPanel.reload(recents: KeyboardPreferences.recentEmojis)
        }
        showsEmoji = visible
        updateVisibility()
        if !visible { afterTextChange() }
    }

    private func insertEmoji(_ emoji: String) {
        feedback()
        pendingAutoSpace = false
        textDocumentProxy.insertText(emoji)
        var recents = KeyboardPreferences.recentEmojis.filter { $0 != emoji }
        recents.insert(emoji, at: 0)
        KeyboardPreferences.recentEmojis = recents
    }

    private func beginSearch() {
        searchQuery = ""
        if page != .letters {
            page = .letters
            buildKeys()
        }
        if shift == .once { setShift(.off) }
        updateVisibility()
        updateSearch()
    }

    private func updateSearch() {
        guard let query = searchQuery else { return }
        topBar.setSearch(query)
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            let recents = KeyboardPreferences.recentEmojis
            resultStrip.show(recents.isEmpty ? ["😀", "😂", "❤️", "👍", "🙏", "🎉", "🔥", "😊", "😍", "🤔", "😭", "👏"] : recents)
        } else {
            resultStrip.show(EmojiCatalog.search(query))
        }
    }

    private func endSearch() {
        searchQuery = nil
        topBar.setSearch(nil)
        updateVisibility()
        afterTextChange()
    }

    // MARK: - Appearance

    private func applyTheme(force: Bool = false) {
        // Always follows the system: the backdrop behind the keys is drawn by iOS,
        // so a forced light or dark keyboard would clash with it.
        let dark = traitCollection.userInterfaceStyle == .dark || textDocumentProxy.keyboardAppearance == .dark
        let next: KeyboardTheme = dark ? .dark : .light
        guard force || next != theme else { return }
        theme = next
        rows.forEach { row in row.keys.forEach { $0.theme = theme } }
        topBar.apply(theme: theme)
        pillRow.apply(theme: theme)
        resultStrip.apply(theme: theme)
        emojiPanel.apply(theme: theme)
        keyPreview.apply(theme: theme)
        settingsPanel.backgroundColor = theme.panel
    }

    // MARK: - Settings panel

    @objc private func toggleSettings() {
        feedback()
        if !settingsPanel.isHidden {
            settingsPanel.isHidden = true
            return
        }
        settingsPanel.subviews.forEach { $0.removeFromSuperview() }
        settingsPanel.backgroundColor = theme.panel
        settingsPanel.layer.cornerRadius = 22
        settingsPanel.layer.cornerCurve = .continuous
        settingsPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        settingsPanel.clipsToBounds = true

        let title = UILabel()
        title.text = "Keyboard settings"
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        done.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, UIView(), done])

        let layoutControl = UISegmentedControl(items: KeyboardLayoutID.allCases.map(\.shortName))
        layoutControl.selectedSegmentIndex = KeyboardLayoutID.allCases.firstIndex(of: layoutID) ?? 0
        layoutControl.addTarget(self, action: #selector(layoutChanged(_:)), for: .valueChanged)
        let layoutRow = UIStackView(arrangedSubviews: [UILabel.makeCaption("Layout and dictation language"), UIView(), layoutControl])
        layoutRow.alignment = .center

        let haptics = UISwitch()
        haptics.isOn = KeyboardPreferences.haptics
        haptics.addTarget(self, action: #selector(toggleHaptics(_:)), for: .valueChanged)
        let sounds = UISwitch()
        sounds.isOn = KeyboardPreferences.sounds
        sounds.addTarget(self, action: #selector(toggleSounds(_:)), for: .valueChanged)
        let autoCap = UISwitch()
        autoCap.isOn = KeyboardPreferences.autoCapitalize
        autoCap.addTarget(self, action: #selector(toggleAutoCap(_:)), for: .valueChanged)
        let autoCorrect = UISwitch()
        autoCorrect.isOn = KeyboardPreferences.autoCorrect
        autoCorrect.addTarget(self, action: #selector(toggleAutoCorrect(_:)), for: .valueChanged)
        let popups = UISwitch()
        popups.isOn = KeyboardPreferences.keyPopups
        popups.addTarget(self, action: #selector(togglePopups(_:)), for: .valueChanged)
        let smart = UISwitch()
        smart.isOn = KeyboardPreferences.smartDictation
        smart.addTarget(self, action: #selector(toggleSmartDictation(_:)), for: .valueChanged)
        let onDevice = UISwitch()
        onDevice.isOn = KeyboardPreferences.onDeviceDictation
        onDevice.addTarget(self, action: #selector(toggleOnDevice(_:)), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [
            header,
            layoutRow,
            makeSettingRow("Haptics", haptics),
            makeSettingRow("Key sounds", sounds),
            makeSettingRow("Auto-capitalise", autoCap),
            makeSettingRow("Auto-correct", autoCorrect),
            makeSettingRow("Key pop-ups", popups),
            makeSettingRow("Tidy dictation and voice commands", smart),
            makeSettingRow("Dictate on device only (slower)", onDevice)
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(14, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Scrolls in landscape, where the keyboard is shorter than the list.
        let scroll = UIScrollView()
        // The iOS 26 scroll edge effect would blur the panel's own header.
        if #available(iOS 26.0, *) { scroll.topEdgeEffect.isHidden = true }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        settingsPanel.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: settingsPanel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: settingsPanel.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: settingsPanel.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: settingsPanel.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12)
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
        refreshSuggestions()
    }

    @objc private func toggleHaptics(_ sender: UISwitch) { KeyboardPreferences.haptics = sender.isOn }
    @objc private func toggleSounds(_ sender: UISwitch) { KeyboardPreferences.sounds = sender.isOn }
    @objc private func toggleAutoCap(_ sender: UISwitch) { KeyboardPreferences.autoCapitalize = sender.isOn }
    @objc private func toggleAutoCorrect(_ sender: UISwitch) {
        KeyboardPreferences.autoCorrect = sender.isOn
        suggestionKey = nil
        refreshSuggestions()
    }

    @objc private func togglePopups(_ sender: UISwitch) { KeyboardPreferences.keyPopups = sender.isOn }
    @objc private func toggleSmartDictation(_ sender: UISwitch) { KeyboardPreferences.smartDictation = sender.isOn }
    @objc private func toggleOnDevice(_ sender: UISwitch) { KeyboardPreferences.onDeviceDictation = sender.isOn }

    // MARK: - Dictation

    private func configureDictation() {
        capture.onAudio = { [weak self] data, rms in self?.append(data, rms: rms) }
        capture.onEnded = { [weak self] reason in self?.captureEnded(reason) }
        capture.attach(to: view)
    }

    private func toggleDictation() {
        capture.isCapturing ? stopDictation() : startDictation()
    }

    private func startDictation() {
        guard hasFullAccess else {
            return topBar.flashStatus("Turn on Allow Full Access for dict8", seconds: 4)
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            return topBar.flashStatus("Allow the microphone in the dict8 app", seconds: 4)
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            return topBar.flashStatus("Allow speech recognition in the dict8 app", seconds: 4)
        }
        guard capture.isReady else {
            return topBar.flashStatus("Microphone is still getting ready")
        }
        let language = KeyboardPreferences.dictationLanguage ?? definition.localeIdentifier
        dictationLanguage = language
        // Their own names and terms, so the recogniser expects them.
        dictationVocabulary = KeyboardPreferences.customVocabulary + personal.data.vocabulary(limit: 60)
        // Creating a recogniser is slow, so each language keeps its own.
        let speech = recognizers[language] ?? SFSpeechRecognizer(locale: Locale(identifier: language))
        guard let speech, speech.isAvailable else {
            return topBar.flashStatus("Speech recognition is unavailable for \(language)", seconds: 4)
        }
        recognizers[language] = speech
        speechRecognizer = speech
        didSwitchMode = false
        insertedPartial = ""
        committedUtterances = 0
        lastCommitted = ""
        committedShown = []
        capturedSamples = 0
        speechError = nil
        typedLetters = []
        lastAutocorrect = nil
        if searchQuery != nil { endSearch() }

        // Apple's server recognition is the default: it is quicker and more accurate than the
        // on-device model. The on-device model is used when asked for, or when offline.
        beginTask(onDevice: KeyboardPreferences.onDeviceDictation && speech.supportsOnDeviceRecognition)
        capture.start()
        topBar.setRecording(true)
    }

    private func beginTask(onDevice: Bool) {
        guard let speechRecognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        request.contextualStrings = dictationVocabulary
        if onDevice { request.requiresOnDeviceRecognition = true }
        usingOnDevice = onDevice
        self.request = request
        taskGeneration += 1
        taskStartedAt = Date()
        let generation = taskGeneration
        task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, generation == self.taskGeneration else { return }
                self.handle(result: result, error: error)
            }
        }
    }

    private func stopDictation() {
        capture.stop()
    }

    private func captureEnded(_ reason: String) {
        log.info("capture ended: \(reason, privacy: .private)")
        request?.endAudio()
        topBar.setRecording(false)
        if reason != "stopped" {
            topBar.flashStatus("Dictation stopped: \(reason)", seconds: 4)
        } else if let speechError {
            topBar.flashStatus("Speech: \(speechError)", seconds: 4)
        } else if insertedPartial.isEmpty, committedUtterances == 0, capturedSamples > 0 {
            topBar.flashStatus("Didn't catch that")
        }
    }

    private func append(_ data: Data, rms: Float) {
        let frames = AVAudioFrameCount(data.count / 2)
        guard frames > 0 else { return }
        capturedSamples += Int(frames)
        // Audio arrives about 47 times a second; the meter only needs a third of that.
        levelTick += 1
        if levelTick % 3 == 0 {
            topBar.updateLevel(rms, seconds: Double(capturedSamples) / WebAudioCapture.sampleRate)
        }

        guard let request, let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        data.withUnsafeBytes { raw in
            buffer.int16ChannelData![0].update(from: raw.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        request.append(buffer)
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                // After earlier utterances were committed, the final result only matters
                // if it still continues the one being typed.
                let continues = committedUtterances == 0
                    || (!insertedPartial.isEmpty && text.hasPrefix(String(insertedPartial.prefix(8))))
                if continues { replacePartial(with: text) }
                if capture.isCapturing, Date().timeIntervalSince(taskStartedAt) > 2 {
                    // The recogniser closed the request itself (server requests last about a
                    // minute). The microphone is still on, so carry on in a new request.
                    commitUtterance()
                    beginTask(onDevice: usingOnDevice)
                } else {
                    capture.stop()
                    finishRecognition()
                }
            } else {
                replacePartial(with: text)
                // The recogniser marks the end of an utterance with metadata, then starts
                // its transcript again from empty.
                if result.speechRecognitionMetadata != nil { commitUtterance() }
            }
        } else if let error {
            log.error("recognition error: \(error.localizedDescription, privacy: .private)")
            let other = !usingOnDevice
            if capture.isCapturing, !didSwitchMode, let speechRecognizer,
               !other || speechRecognizer.supportsOnDeviceRecognition {
                // One mode failed (offline, or no on-device model): keep the same microphone
                // stream and try the other once.
                didSwitchMode = true
                commitUtterance()
                beginTask(onDevice: other)
                topBar.flashStatus(other ? "Using on-device recognition" : "Using network recognition", seconds: 1.5)
                return
            }
            if capture.isCapturing {
                speechError = error.localizedDescription
                task = nil
                request = nil
            } else {
                finishRecognition()
            }
        }
    }

    /// Keeps what has been typed and starts a fresh utterance after it.
    private func commitUtterance() {
        guard !insertedPartial.isEmpty else { return }
        let raw = insertedPartial
        var shown = formatFinishedUtterance()
        if !shown.isEmpty, !shown.hasSuffix("\n") {
            textDocumentProxy.insertText(" ")
            shown += " "
        }
        lastCommitted = raw
        committedShown.append(shown)
        insertedPartial = ""
        committedUtterances += 1
    }

    /// Tidies the utterance the recogniser has finished with, in place, and returns
    /// what the document now holds for it.
    private func formatFinishedUtterance() -> String {
        guard KeyboardPreferences.smartDictation else { return insertedPartial }
        let result = DictationFormatter.format(insertedPartial, language: dictationLanguage)
        var typed = insertedPartial
        if result.deletesPrevious {
            // "Scratch that": remove this utterance and the one before it.
            let earlier = committedShown.popLast() ?? lastSentenceBeforeCursor(skipping: typed.count)
            for _ in 0..<(typed.count + earlier.count) { textDocumentProxy.deleteBackward() }
            typed = ""
        }
        if result.text != typed {
            let common = zip(typed, result.text).prefix { $0 == $1 }.count
            for _ in 0..<(typed.count - common) { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(String(result.text.dropFirst(common)))
        }
        return result.text
    }

    /// The sentence that ends where this dictation began, for "scratch that" said first.
    private func lastSentenceBeforeCursor(skipping count: Int) -> String {
        let before = String((textDocumentProxy.documentContextBeforeInput ?? "").dropLast(count))
        var characters = Array(before)
        var taken: [Character] = []
        while let last = characters.last, last == " " || ".!?".contains(last) { taken.append(characters.removeLast()) }
        while let last = characters.last, !".!?\n".contains(last) { taken.append(characters.removeLast()) }
        return String(taken.reversed())
    }

    private func replacePartial(with text: String) {
        guard text != insertedPartial else { return }
        // The transcript carried on after all instead of restarting: take the commit back
        // so the same words are not typed twice.
        if insertedPartial.isEmpty, !lastCommitted.isEmpty, text.hasPrefix(lastCommitted),
           let shown = committedShown.popLast() {
            for _ in shown { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(lastCommitted)
            insertedPartial = lastCommitted
            lastCommitted = ""
            committedUtterances -= 1
            guard text != insertedPartial else { return }
        }
        var common = zip(insertedPartial, text).prefix { $0 == $1 }.count
        // After a pause the recogniser restarts its transcript, so the new text is short and
        // unrelated to the old. That is a new utterance, not a correction: keep the old text.
        let shrink = insertedPartial.count - text.count
        let endedSentence = insertedPartial.last.map { ".?!".contains($0) } ?? false
        let restarted = shrink > 0
            && ((common == 0 && endedSentence) || (shrink >= 8 && text.count * 10 < insertedPartial.count * 6))
        if restarted {
            commitUtterance()
            common = 0
        }
        for _ in 0..<(insertedPartial.count - common) { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(String(text.dropFirst(common)))
        insertedPartial = text
    }

    private func finishRecognition() {
        task = nil
        request = nil
        if !insertedPartial.isEmpty {
            let shown = formatFinishedUtterance()
            // Leave the cursor ready for the next word.
            if !shown.isEmpty, !shown.hasSuffix("\n") { textDocumentProxy.insertText(" ") }
        }
        insertedPartial = ""
        committedShown = []
        topBar.setRecording(false)
        afterTextChange()
    }
}

private extension UILabel {
    static func makeCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        return label
    }
}

/// The enlarged letter shown above a key while it is pressed.
final class KeyPreviewView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
        label.font = .systemFont(ofSize: 32, weight: .regular)
        label.textAlignment = .center
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
        apply(theme: .dark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme: KeyboardTheme) {
        backgroundColor = theme.isDark ? theme.keyPressed : .white
        label.textColor = theme.label
    }

    func show(_ text: String) {
        label.frame = bounds
        label.text = text
        isHidden = false
    }
}
