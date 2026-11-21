import SwiftUI
import AVFoundation
import Speech

struct RootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            SetupView()
                .tabItem { Label("Setup", systemImage: "keyboard") }
                .tag(0)
            TestView()
                .tabItem { Label("Try it", systemImage: "text.cursor") }
                .tag(1)
        }
        .tint(.blue)
        .onAppear {
            #if targetEnvironment(simulator)
            selection = 1
            #endif
        }
    }
}

struct SetupView: View {
    @State private var micGranted = AVAudioApplication.shared.recordPermission == .granted
    @State private var speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    @State private var layout: KeyboardLayoutID = KeyboardPreferences.layout
    @State private var haptics = KeyboardPreferences.haptics
    @State private var sounds = KeyboardPreferences.sounds
    @State private var autoCapitalize = KeyboardPreferences.autoCapitalize
    @State private var onDeviceDictation = KeyboardPreferences.onDeviceDictation
    @State private var autoCorrect = KeyboardPreferences.autoCorrect
    @State private var didResetLearning = false
    @State private var keyPopups = KeyboardPreferences.keyPopups
    @State private var smartDictation = KeyboardPreferences.smartDictation
    @State private var dictationLanguage = KeyboardPreferences.dictationLanguage ?? ""
    @State private var vocabulary = KeyboardPreferences.customVocabulary.joined(separator: "\n")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    steps
                    permissions
                    settings
                    dictation
                    footer
                }
                .padding(20)
            }
            .navigationTitle("dict8")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type with your voice")
                        .font(.title2.weight(.semibold))
                    Text("A keyboard that dictates inside any app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepRow(number: 1,
                    title: "Turn on the keyboard",
                    detail: "Settings › General › Keyboard › Keyboards › Add New Keyboard › dict8.")
            Button {
                openKeyboardSettings()
            } label: {
                Label("Open keyboard settings", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            StepRow(number: 2,
                    title: "Allow Full Access",
                    detail: "Tap dict8 in the keyboard list and switch on Allow Full Access. Dictation needs it for the microphone.")

            StepRow(number: 3,
                    title: "Dictate anywhere",
                    detail: "In any app, switch to dict8 and tap the microphone key. Text appears as you speak.")
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.headline)
            PermissionRow(title: "Microphone", granted: micGranted)
            PermissionRow(title: "Speech recognition", granted: speechGranted)
            if !micGranted || !speechGranted {
                Button {
                    requestPermissions()
                } label: {
                    Label("Grant permissions", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard settings")
                .font(.headline)

            Picker("Layout", selection: $layout) {
                ForEach(KeyboardLayoutID.allCases) { id in
                    Text(id.displayName).tag(id)
                }
            }
            .onChange(of: layout) { _, newValue in KeyboardPreferences.layout = newValue }

            Toggle("Haptics", isOn: $haptics)
                .onChange(of: haptics) { _, newValue in KeyboardPreferences.haptics = newValue }
            Toggle("Key sounds", isOn: $sounds)
                .onChange(of: sounds) { _, newValue in KeyboardPreferences.sounds = newValue }
            Toggle("Auto-capitalise", isOn: $autoCapitalize)
                .onChange(of: autoCapitalize) { _, newValue in KeyboardPreferences.autoCapitalize = newValue }
            Toggle("Key pop-ups", isOn: $keyPopups)
                .onChange(of: keyPopups) { _, newValue in KeyboardPreferences.keyPopups = newValue }
            Toggle("Auto-correct", isOn: $autoCorrect)
                .onChange(of: autoCorrect) { _, newValue in KeyboardPreferences.autoCorrect = newValue }
            Button(didResetLearning ? "Learned typing cleared" : "Reset learned typing", role: .destructive) {
                KeyboardPreferences.personalModel = nil
                didResetLearning = true
            }
            .disabled(didResetLearning)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Languages the speech recogniser offers, by name.
    private var dictationLanguages: [(id: String, name: String)] {
        SFSpeechRecognizer.supportedLocales()
            .map { (id: $0.identifier, name: Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
            .sorted { $0.name < $1.name }
    }

    private var dictation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dictation")
                .font(.headline)

            Picker("Language", selection: $dictationLanguage) {
                Text("Same as keyboard").tag("")
                ForEach(dictationLanguages, id: \.id) { language in
                    Text(language.name).tag(language.id)
                }
            }
            .onChange(of: dictationLanguage) { _, newValue in
                KeyboardPreferences.dictationLanguage = newValue.isEmpty ? nil : newValue
            }

            Toggle("Tidy dictation and voice commands", isOn: $smartDictation)
                .onChange(of: smartDictation) { _, newValue in KeyboardPreferences.smartDictation = newValue }
            Text("Drops “um” and repeated words when you stop. In English, say “new line”, “new paragraph” or “scratch that”.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Dictate on device only (slower)", isOn: $onDeviceDictation)
                .onChange(of: onDeviceDictation) { _, newValue in KeyboardPreferences.onDeviceDictation = newValue }

            Text("Names and terms")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $vocabulary)
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .autocorrectionDisabled()
                .onChange(of: vocabulary) { _, newValue in
                    KeyboardPreferences.customVocabulary = newValue
                        .split(whereSeparator: \.isNewline)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            Text("One per line. Dictation listens for these, so names and jargon come out right.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var footer: some View {
        Text("Settings are shared with the keyboard when the app group is available; otherwise change them from the menu button on the keyboard itself.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { speechGranted = status == .authorized }
        }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { micGranted = granted }
        }
    }

    private func openKeyboardSettings() {
        guard let url = URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS") else { return }
        UIApplication.shared.open(url)
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(.blue.opacity(0.15), in: Circle())
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Label(granted ? "Allowed" : "Not allowed",
                  systemImage: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.footnote.weight(.medium))
        }
    }
}

struct TestView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap the field, switch to dict8 with the globe key, then type or dictate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .focused($focused)
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 180)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text("\(text.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { text = "" }
                        .font(.caption)
                        .disabled(text.isEmpty)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Try it")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focused = true }
        }
    }
}
