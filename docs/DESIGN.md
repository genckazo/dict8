# dict8 — design spec

The keyboard is drawn on the system keyboard backdrop: it paints no background of its own, so its keys sit on the same surface as the globe strip iOS draws underneath. Values below are the ones the shipped code uses (`KeyboardExt/KeyboardTheme.swift`, `KeyRowView.swift`, `TopBarView.swift`, `ActionPillRow.swift`).

## Figma

Drag `docs/dict8-keyboard.figma.svg` into a Figma page. It lands as vector layers named per part (`keyboard-dark-letters`, `top-bar`, `pill-search`, `row-2`, `key-Q`) at 1 unit = 1 pt. Regenerate it with `python3 scripts/make_figma_board.py` after a token change. The board has four frames: dark, dictating, numbers page, light. Icons on the board are simple stand-ins for the SF Symbols the app uses.

## Structure, top to bottom

| Part | Contents |
|---|---|
| Top bar | menu button (opens settings) · three word suggestions · voice button |
| Action pills | fix spelling · paste · emoji search · polish |
| Keys | three letter rows and the bottom row: `123`, emoji, space, return |
| System strip | globe and system dictation, drawn by iOS |

The middle suggestion is drawn brighter and in medium weight when it is the word autocorrect will apply. While dictating, the suggestions are replaced by a live level meter and a timer, and the voice button turns into a red stop button. Status messages and the emoji search query use the same middle section.

## Tokens

| Token | Dark | Light |
|---|---|---|
| Key and pill | `#454547` | `#FFFFFF` |
| Key pressed | `#6B6B6E` | `#C7C9D1` |
| Label and icons | `#FFFFFF` | `#000000` |
| Suggestion text | white 62% grey | white 38% grey |
| Divider | white 14% | black 16% |
| Voice button | white, black icon | black, white icon |
| Voice button, recording | `#FF453A`, white icon | same |
| Settings panel | `#2B2B2D` | `#D1D4DB` |

Light or dark follows the system and the host app's keyboard appearance. There is no manual override, because the backdrop is drawn by iOS and cannot be restyled from the extension.

## Metrics (402 pt wide phone, portrait)

| Item | Value |
|---|---|
| Keyboard view height | 319 pt on iOS 26 and later (the system adds about 15 pt above it), 332 pt before |
| Top bar | 56 pt tall; voice button 36 pt circle, 30 pt from the right edge |
| Suggestions | three equal columns between x = 57 and width − 57; 18 pt regular |
| Action pills | 40 pt tall capsules, 8 pt side inset, 8 pt gap |
| Key row pitch | 54 pt; keys 42.3 pt tall |
| Key width | one tenth of the row: (width − 13 − 9 × 6) / 10 ≈ 33.5 pt |
| Key gap | 6 pt; side inset 6.5 pt |
| Key corner radius | 5.5 pt, continuous |
| Shift, delete, 123, emoji | 1.35 × key width |
| Return | 2.75 × key width |
| Letter label | 23 pt regular; `123`, `ABC`, `#+=` 16 pt |
| Touch targets | each key reaches halfway into the gaps around it |
| Key pop-up | 54 pt tall, key width + 14 pt (46 pt minimum), 32 pt letter, radius 9, above the pressed key |

Landscape drops the pill row and uses a 40 pt top bar and 40 pt row pitch (206 pt in total).

## Layouts

- QWERTY — `qwertyuiop / asdfghjkl / ⇧zxcvbnm⌫`
- QWERTZ — `qwertzuiop / asdfghjkl / ⇧yxcvbnm⌫`, accents on a o u s (ä ö ü ß)
- Turkish QWERTY — `qwertyuıop / asdfghjkl / ⇧zxcvbnm⌫`, accents on g u i ı o c s (ğ ü ı ö ç ş)

Pages: letters, `123`, `#+=`, emoji. Accent menus are long-press and follow shift. The layout also sets the language for suggestions, spelling fixes and dictation.
