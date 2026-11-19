# Voice Keyboard — On-device Acceptance Checklist

Status: NOT RUN. No device install yet (free-profile slot blocker). Do not mark PASS until executed on the iPhone 16 Pro.

Device: iPhone 16 Pro (00008140-0009542C3688801C), iOS 18.x.
Build under test: Release, team 5YKGZQWSA3, VoiceKeyboard.app + VoiceKeyboardKeyboard.appex.
Known open code issues (Change Reviewer): backspace has no auto-repeat, dictation does not stop on final result, accent long-press ignores one-shot shift, layout switch drops shift title. Verify these are fixed before running, or expect FAIL.

Result key: PASS / FAIL / BLOCKED. Attach screenshot per item.

## 0. Prerequisites
0.1 Install app on phone. Steps: remove one free-profile app (LiveContainer) to free slot; install build/ipa/VoiceKeyboard.ipa. Expected: app icon appears, launches to onboarding. Pass/Fail: ___

## 1. Keyboard discovery & activation
1.1 Settings > General > Keyboard > Keyboards lists "Voice Keyboard". Steps: open Settings, navigate. Expected: entry present. Pass/Fail: ___
1.2 Enable it. Steps: tap Keyboards > Add New Keyboard > Voice Keyboard. Expected: appears in list, no crash. Pass/Fail: ___
1.3 Activate in a text field. Steps: open Messages, tap compose, globe/hold space, select Voice Keyboard. Expected: keyboard renders, 268pt portrait height, no crash. Pass/Fail: ___
1.4 Full Access toggle. Steps: Settings > Voice Keyboard > Allow Full Access on. Expected: toggle flips, no crash; off-state shows "Enable Allow Full Access". Pass/Fail: ___

## 2. Layout switching (gear panel)
2.1 Open gear panel. Steps: tap gear icon top-right. Expected: panel overlays keyboard with Layout segmented control (QWERTY/QWERTZ/Turkish), Haptics/Key sounds/Auto-capitalize switches, Appearance control, Done. Pass/Fail: ___
2.2 Switch QWERTY -> QWERTZ. Steps: segmented control middle. Expected: row2 has Y/Z swapped (QWERTZ), shift title retained. Pass/Fail: ___
2.3 Switch to Turkish. Expected: rows show Turkish layout (ı, ş, ğ, ü, ö, ç present). Pass/Fail: ___
2.4 Switch back to QWERTY. Expected: original layout restored. Pass/Fail: ___
2.5 Persistence. Steps: dismiss keyboard, reopen. Expected: last chosen layout retained (KeyboardPreferences). Pass/Fail: ___

## 3. Shift
3.1 Shift once. Steps: tap ⇧, tap a letter. Expected: letter uppercase, ⇧ returns to lowercase state. Pass/Fail: ___
3.2 Caps lock. Steps: double-tap ⇧ (off->once->caps). Expected: ⇧ shows ⇪, all letters uppercase until tapped again. Pass/Fail: ___
3.3 Auto-capitalize. Steps: with Auto-capitalize on, type ". " then a letter. Expected: next letter auto-capitalized. Pass/Fail: ___

## 4. Backspace
4.1 Single delete. Steps: type "abc", tap ⌫ once. Expected: "ab". Pass/Fail: ___
4.2 Auto-repeat. Steps: hold ⌫. Expected: deletes continuously until release (KNOWN BUG: repeatAction nil). Pass/Fail: ___

## 5. Return key labels
5.1 Messages compose: label "send"/"return". Notes: "return". Safari address bar: "go"/"search". Expected: matches textDocumentProxy.returnKeyType. Pass/Fail: ___

## 6. ?123 and #+= pages
6.1 Tap "123". Expected: number row 1-0, second row symbols, third row "#+=" etc. Pass/Fail: ___
6.2 Tap "#+=". Expected: symbols page. Pass/Fail: ___
6.3 Tap "ABC". Expected: letters page restored, current layout. Pass/Fail: ___

## 7. Accent long-press
7.1 Long-press 'a' (QWERTY). Expected popup with ä (and related). Insert ä. Pass/Fail: ___
7.2 Long-press o/u/s. Expected: ö, ü, ß. Pass/Fail: ___
7.3 Turkish accents. Steps: switch to Turkish, long-press g/u/s/i/o/c. Expected: ğ ü ş ı ö ç. Pass/Fail: ___
7.4 Shift + accent. Steps: shift once, long-press base, pick accent. Expected: uppercase accent (KNOWN BUG: accentMenu only caps on .caps). Pass/Fail: ___

## 8. Haptics & sounds
8.1 Haptics on. Steps: toggle on, type. Expected: light impact per key. Pass/Fail: ___
8.2 Haptics off. Expected: no haptic. Pass/Fail: ___
8.3 Key sounds on/off. Expected: AudioServicesPlaySystemSound 1104 when on. Pass/Fail: ___

## 9. Appearance
9.1 Light. Steps: gear > Appearance > Light. Expected: light keyboard, persists. Pass/Fail: ___
9.2 Dark. Expected: dark keyboard. Pass/Fail: ___
9.3 System. Steps: set System, toggle device dark mode. Expected: keyboard follows (traitCollectionDidChange). Pass/Fail: ___

## 10. Landscape
10.1 Rotate to landscape. Expected: height 210pt, no clipping, rows fit. Pass/Fail: ___
10.2 Rotate back to portrait. Expected: 268pt restored. Pass/Fail: ___

## 11. Dictation
11.1 Permission prompts. Steps: tap 🎤 with no mic/speech permission. Expected: status "Grant microphone access..." / "Grant speech recognition..."; no crash. (Permissions granted in containing app first.) Pass/Fail: ___
11.2 Grant in containing app. Steps: open Voice Keyboard app, grant Microphone + Speech Recognition. Expected: toggles/permissions set. Pass/Fail: ___
11.3 Partial text. Steps: tap 🎤, speak a sentence. Expected: status "Listening Xs", partial transcription inserts into field and updates in place. Pass/Fail: ___
11.4 Stop. Steps: tap 🎤 again (or stop). Expected: capture stops, status "Inserted"/"Done", mic icon not recording. (KNOWN BUG: may keep recording after final.) Pass/Fail: ___
11.5 Insertion targets. Steps: dictation in Messages, Notes, Safari. Expected: text lands in each field. Pass/Fail: ___
11.6 Full Access off. Steps: disable Allow Full Access, tap 🎤. Expected: status "Enable Allow Full Access for this keyboard.", no capture. Pass/Fail: ___
11.7 Offline recognition. Steps: airplane mode, dictate. Expected: if requiresOnDeviceRecognition set, works offline; otherwise status error. (Security: default may use network.) Pass/Fail: ___

## 12. 7-day free-profile expiry
12.1 Record install date. Expected: expiry = install + 7 days. Pass/Fail: ___
12.2 After expiry: app/keyboard fail to launch or show provisioning error. Steps: advance date (cannot easily; note date). Expected: documented. Pass/Fail: N/A until date.

## What cannot be checked without the phone
- All items above require device install (blocked by free-profile 3-app limit).
- Haptics, sounds, landscape transition, dictation audio capture, mic/speech permission prompts, Full Access behavior, 7-day expiry.
- Simulator cannot validate: provisioning/expiry, real permission dialogs, haptics, audio route, WKWebView getUserMedia on device.
- Cannot verify network traffic / on-device recognition without packet capture and device logs.

## Evidence
Attach screenshots per item with attach_files_to_response. Mark final verdict: PASS / FAIL / BLOCKED.