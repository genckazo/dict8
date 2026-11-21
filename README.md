# dict8

![dict8 keyboard](docs/showcase.png)

A native iOS keyboard extension with on-device voice dictation. Type with your voice in any app — Messages, Notes, Safari, Mail — without switching apps or granting network access beyond what speech recognition needs.

## Features

- **Voice dictation** — tap the round voice button, speak, and text appears live. A level meter and timer show while it listens; tap again to stop. Long dictations carry on past the recogniser's one-minute limit.
- **Tidy dictation** — when you stop, filler sounds ("um", "uh") and accidentally repeated words are dropped. In English, say "new line", "new paragraph" or "scratch that".
- **Names and terms** — list names and jargon in the app and dictation listens for them. Words the keyboard has learned from your typing are included.
- **Dictation language** — follows the keyboard layout or any language the recogniser supports.
- **Autocorrect that learns you** — fixes slips when you finish a word, judging them by which keys sit next to each other and where your own taps tend to land. One backspace puts back what you typed, and it leaves that word alone from then on. Words you use that the dictionary does not know are learned and suggested. Everything it learns stays on the phone and can be reset in the app.
- **Next-word prediction** — before you start a word, the bar offers what you usually type after the last one.
- **Text replacements and contacts** — shortcuts from iOS Settings expand as you type, and contact names are never "corrected".
- **Word suggestions** — completions and corrections for the word being typed, from the system dictionary.
- **Action pills** — fix spelling in what you just wrote, paste, search emoji by name, and polish text with the on-device Apple Intelligence model (iOS 26 or later). Hold the polish pill for shorter, more formal or friendlier rewrites.
- **Emoji picker** — categories, recents, and flags.
- **Three layouts** — QWERTY, QWERTZ, and Turkish, selectable in the app or from the menu button on the keyboard.
- **123 and #+= pages** — numbers, punctuation, and symbols.
- **Long-press accents** — ä ö ü ß, ğ ü ş ı ö ç and more.
- **Typing comforts** — key pop-ups, shift and double-tap caps lock, auto-capitalise, double-space full stop, hold delete to erase whole words, hold space to move the cursor.
- **Haptics and key sounds** — both toggleable.
- **Light and dark** — follows the system.
- **Return key label** — go, search, send, done, etc. based on the host app.
- **Onboarding + test field** in the containing app, plus a settings panel on the keyboard itself.
- **App Group sharing** — settings sync between the app and the extension.

## Requirements

- iOS 17.0+
- Xcode 15+
- A device with a microphone for dictation (simulator supports typing only)

## Install

1. Open `VoiceKeyboard.xcodeproj` in Xcode.
2. Select your development team in both targets (app + keyboard extension).
3. Build and run on a device.
4. On the device: **Settings → General → Keyboard → Keyboards → Add New Keyboard → dict8**, then tap it and enable **Allow Full Access** (required for the microphone).
5. In any text field, switch to dict8 with the globe key and tap the mic.

## Project layout

```
VoiceKeyboard/          # Containing app (SwiftUI onboarding + test field)
KeyboardExt/            # Keyboard extension (UIKit)
Shared/                 # Shared models + preferences (App Group)
docs/                   # Design spec + showcase image
scripts/                # Project and asset generators
VoiceKeyboard.xcodeproj
```

## Design

Key sizes, colours, spacing, and the Figma status are documented in [`docs/DESIGN.md`](docs/DESIGN.md). The showcase image is rendered from the same tokens by `scripts/make_showcase.swift`.

## Privacy

- Dictation uses Apple's speech recognition, which sends audio to Apple's servers when online because it is quicker and more accurate. Turn on "Dictate on device only" to keep audio on the phone.
- What the keyboard learns from your typing (words, word pairs, tap positions) is stored only on the phone and is never sent anywhere. It does not learn in web address, email or number fields.
- The microphone is never granted to a non-local page; navigation is limited to the local capture page.
- Logs use `.private` for transcript and error text.
- No audio or text is stored or transmitted beyond what `SFSpeechRecognizer` requires.

## Security

See the security review notes: `RequestsOpenAccess` is required for microphone + speech recognition. If you want an offline-only build, set it to `false` in `KeyboardExt/Info.plist` and remove network entitlements.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built on top of [stephancill/ios-keyboard-dictation](https://github.com/stephancill/ios-keyboard-dictation). Native rewrite with layouts, ?123 page, haptics, appearance, onboarding, and hardening.