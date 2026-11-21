# dict8 2.1 — on-device acceptance checklist

Run on a real iPhone; the simulator has no microphone and its taps always land dead centre.
Result key: PASS / FAIL / BLOCKED.

Status at release: sections 1–3 were exercised in the simulator. Dictation of several sentences was confirmed on an iPhone 16 Pro (iOS 27.0). Everything marked *device* is otherwise unverified.

## 1. Setup
1.1 Settings → General → Keyboard → Keyboards → Add New Keyboard → dict8. Expected: listed and selectable.
1.2 Allow Full Access on. Expected: voice button and paste work; with it off they explain what is missing.
1.3 Microphone and speech recognition granted in the dict8 app.

## 2. Typing
2.1 Letters, shift, double-tap caps lock, auto-capitalise after a full stop.
2.2 Double space types a full stop. Hold delete erases letters, then whole words.
2.3 `123` and `#+=` pages; space returns to letters.
2.4 Key pop-up appears above a held letter and goes away on release. Off when "Key pop-ups" is off.
2.5 Hold space, drag: the cursor moves. *device*
2.6 Long-press accents on the German and Turkish layouts. *device*
2.7 Landscape: pill row hidden, keys fit. *device*
2.8 Return key reads go / search / send in fields that ask for it. *device*

## 3. Suggestions and autocorrect
3.1 Type "teh" + space → "The". The pending correction is the brighter middle suggestion.
3.2 Backspace straight after → "Teh" comes back and the bar says it was kept. Typing "teh" again is left alone.
3.3 "helo" → "hello"; "dont" → "don't".
3.4 Type "good" + space → the bar offers "morning", "night", "luck".
3.5 An unknown word typed twice and kept is no longer corrected and is suggested. *device*
3.6 A text replacement from iOS Settings expands on space. A contact's name is not corrected. *device*
3.7 After a day of typing, edge taps resolve to the intended key. "Reset learned typing" in the app clears it. *device*
3.8 No autocorrect in a web address or email field. *device*

## 4. Dictation — all *device*
4.1 Tap the voice button: level meter and timer show, text appears as you speak, tap again to stop.
4.2 Several sentences with pauses: every sentence is kept.
4.3 Dictate for more than a minute without stopping: nothing is lost at the hand-over.
4.4 Say "um" and repeat a word: both are gone after you stop.
4.5 "new line", "new paragraph", "scratch that" act as commands (English).
4.6 A name listed under "Names and terms" is recognised.
4.7 Dictation language set to something other than the layout is used.
4.8 "Dictate on device only" on, airplane mode: still works.
4.9 Airplane mode with the switch off: falls back to on-device once and says so.

## 5. Pills
5.1 Fix spelling corrects misspelt words before the cursor.
5.2 Paste inserts the clipboard. *device*
5.3 Emoji search finds emoji by name; the emoji key opens the picker with recents.
5.4 Polish rewrites the text; holding the pill offers shorter / more formal / friendlier. Needs Apple Intelligence. *device*

## 6. Appearance
6.1 Dark and light follow the system. *device for light*
