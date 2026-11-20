# dict8 — design spec

The keyboard follows the system keyboard's proportions with a darker, softer key treatment. Values below are the ones the shipped code uses; change them in one place and both the keyboard and the showcase render follow.

## Figma status

Figma is connected through the desktop MCP, but that MCP can only read a design (`get_design_context`, `get_metadata`, `get_screenshot`, Code Connect). It cannot create frames, so the design cannot be drawn in Figma from here. The open file contains one empty page.

To bring the design into Figma, either:

1. paste `docs/showcase.png` into a new frame and send the frame URL — then colours, type and spacing can be pulled back for comparison, or
2. create the frame with these tokens; they map 1:1 to the code.

## Tokens

| Token | Dark | Light |
|---|---|---|
| Keyboard background | `#1C1C1E` (white 0.11) | `#D4D4D4` (white 0.83) |
| Character key | `#3B3B3D` (white 0.23) | `#FFFFFF` |
| Special key (shift, delete, 123, globe, return) | `#4A4A4C` (white 0.29) | `#D1D1D6` (white 0.82) |
| Key label | `#FFFFFF` | `#000000` |
| Mic (idle) | special key | special key |
| Mic (recording) | `#FF453A` | `#FF453A` |

## Metrics

| Item | Value |
|---|---|
| Keyboard height, portrait | 292 pt |
| Keyboard height, landscape | 236 pt |
| Key corner radius | 9 pt (showcase 12 pt at 2×) |
| Key gap | 6 pt |
| Row gap | 7 pt |
| Outer padding | 3 pt horizontal, 4 pt vertical |
| Suggestion/status strip | 30 pt |
| Letter label | 22 pt regular, auto-shrinks to 60% |
| Special key label | 15 pt medium |
| Bottom row weights | 1.2 · 1.1 · 1.2 · 4.4 · 1.7 |
| Row weights | letters 1, shift/delete 1.45 |
| Key shadow | black 14%, radius 1, offset 0/1 |

## Reference image

The design brief was a screenshot of a dark messaging app with a rounded-key keyboard. What was taken from it: dark key wells on a darker background, generous 9–12 pt corners, key labels in regular weight, a wide space bar with the mic treated as a coloured key, and a slim strip above the keys for status.

What was not taken: the app's tool-chip row and its three suggestion words. Those belong to the host app, and dict8 has no prediction engine to fill three real suggestions, so the strip shows the dictation state instead of placeholder text.

## Layouts

- QWERTY — `qwertyuiop / asdfghjkl / ⇧zxcvbnm⌫`
- QWERTZ — `qwertzuiop / asdfghjkl / ⇧yxcvbnm⌫`, accents on a o u s (ä ö ü ß)
- Turkish QWERTY — `qwertyuıop / asdfghjkl / ⇧zxcvbnm⌫`, accents on g u i ı o c s (ğ ü ı ö ç ş)

Pages: letters, `?123`, `#+=`. Accent menus are long-press and follow one-shot shift.
