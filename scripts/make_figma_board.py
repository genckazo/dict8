#!/usr/bin/env python3
"""Render the dict8 keyboard as a Figma-importable SVG design board.

Geometry mirrors KeyboardExt (KeyboardMetrics.portrait, KeyRowView, TopBarView,
ActionPillRow) on a 402 pt wide phone: 15 pt system inset, top bar centred at
43 pt, pills 73-113, four 54 pt key rows from 117.5, keys 42.3 pt tall on a
tenth-of-the-row grid with 6 pt gaps. The strip under the keys (globe, system
dictation) is drawn by iOS, not by the keyboard.

One unit = one point, so the SVG pastes into Figma at real size with named
vector layers. Run: python3 scripts/make_figma_board.py
"""
import os
import sys

W, H, STRIP = 402, 334, 66
FONT = "SF Pro Text, Helvetica Neue, Helvetica, Arial"

THEMES = {
    "dark": dict(backdrop="#2B2B2D", key="#454547", label="#FFFFFF", muted="#9E9E9E",
                 divider="#FFFFFF", divider_opacity="0.14", voice="#FFFFFF", voice_icon="#000000"),
    "light": dict(backdrop="#D1D4DB", key="#FFFFFF", label="#000000", muted="#616161",
                  divider="#000000", divider_opacity="0.16", voice="#000000", voice_icon="#FFFFFF"),
}
RECORDING = "#FF453A"

LETTERS = [list("QWERTYUIOP"), list("ASDFGHJKL"), ["shift"] + list("ZXCVBNM") + ["delete"]]
NUMBERS = [list("1234567890"), list('-/:;()€&@"'), ["#+="] + list(".,?!'") + ["delete"]]


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def text(x, y, s, size, fill, weight=400, anchor="middle"):
    return (f'<text x="{x:.2f}" y="{y:.2f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}" dominant-baseline="central">{esc(s)}</text>')


def icon(name, cx, cy, color, bg):
    """Small stroke icons standing in for the SF Symbols the app uses."""
    s = f'stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"'
    if name == "shift":
        return f'<path d="M{cx} {cy-8} l9 9 h-5 v7 h-8 v-7 h-5 z" fill="{color}"/>'
    if name == "delete":
        return (f'<path d="M{cx-11} {cy} l6 -7 h14 a2 2 0 0 1 2 2 v10 a2 2 0 0 1 -2 2 h-14 z" {s}/>'
                f'<path d="M{cx+1} {cy-3} l6 6 m0 -6 l-6 6" {s}/>')
    if name == "return":
        return f'<path d="M{cx+9} {cy-6} v5 a2 2 0 0 1 -2 2 h-15 m4 -4 l-4 4 l4 4" {s}/>'
    if name == "emoji":
        return (f'<circle cx="{cx}" cy="{cy}" r="10" fill="{color}"/>'
                f'<circle cx="{cx-3.5}" cy="{cy-2.5}" r="1.4" fill="{bg}"/>'
                f'<circle cx="{cx+3.5}" cy="{cy-2.5}" r="1.4" fill="{bg}"/>'
                f'<path d="M{cx-4.5} {cy+2.5} q4.5 5 9 0" stroke="{bg}" stroke-width="1.6" '
                f'stroke-linecap="round" fill="none"/>')
    if name == "grid":
        return "".join(f'<rect x="{cx+dx}" y="{cy+dy}" width="7.6" height="7.6" rx="2" fill="{color}"/>'
                       for dx in (-8.6, 1) for dy in (-8.6, 1))
    if name == "waveform":
        bars = [(-7, 5), (-3.5, 11), (0, 16), (3.5, 9), (7, 5)]
        return "".join(f'<rect x="{cx+dx-0.9}" y="{cy-h/2}" width="1.8" height="{h}" rx="0.9" fill="{color}"/>'
                       for dx, h in bars)
    if name == "stop":
        return f'<rect x="{cx-6}" y="{cy-6}" width="12" height="12" rx="2.5" fill="{color}"/>'
    if name == "proofread":
        return (f'<path d="M{cx-9} {cy-5} l2.5 2.5 l4.5 -5" {s}/>'
                f'<path d="M{cx+2} {cy-5} h7 M{cx-9} {cy+1} h18 M{cx-9} {cy+6} h18" {s}/>')
    if name == "paste":
        return (f'<rect x="{cx-7}" y="{cy-4}" width="9" height="12" rx="2" {s}/>'
                f'<path d="M{cx-3} {cy-4} v-3 a2 2 0 0 1 2 -2 h6 a2 2 0 0 1 2 2 v9 a2 2 0 0 1 -2 2 h-3" {s}/>')
    if name == "search":
        return f'<circle cx="{cx-1.5}" cy="{cy-1.5}" r="6" {s}/><path d="M{cx+3} {cy+3} l5 5" {s}/>'
    if name == "sparkles":
        def star(x, y, r):
            return (f'<path d="M{x} {y-r} q{r*0.18} {r*0.82} {r} {r} q-{r*0.82} {r*0.18} -{r} {r} '
                    f'q-{r*0.18} -{r*0.82} -{r} -{r} q{r*0.82} -{r*0.18} {r} -{r} z" fill="{color}"/>')
        return star(cx + 2, cy + 2, 7) + star(cx - 6, cy - 5, 3.5)
    if name == "globe":
        return (f'<circle cx="{cx}" cy="{cy}" r="11" {s}/><ellipse cx="{cx}" cy="{cy}" rx="5" ry="11" {s}/>'
                f'<path d="M{cx-11} {cy} h22 M{cx-9.5} {cy-5.5} h19 M{cx-9.5} {cy+5.5} h19" {s}/>')
    if name == "mic":
        return (f'<rect x="{cx-4}" y="{cy-12}" width="8" height="15" rx="4" {s}/>'
                f'<path d="M{cx-8} {cy} a8 8 0 0 0 16 0 M{cx} {cy+8} v5 m-5 0 h10" {s}/>')
    return ""


def key(x, y, w, h, label, t, name):
    out = [f'<g id="key-{esc(name)}">',
           f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="5.5" fill="{t["key"]}"/>']
    cx, cy = x + w / 2, y + h / 2
    if label in ("shift", "delete", "return", "emoji"):
        out.append(icon(label, round(cx, 2), round(cy, 2), t["label"], t["key"]))
    elif label:
        out.append(text(cx, cy, label, 16 if len(label) > 1 else 23, t["label"]))
    out.append("</g>")
    return "".join(out)


def key_rows(t, rows, bottom_label):
    inset, gap, pitch, key_h, top = 6.5, 6, 54, 42.3, 117.5
    unit = (W - inset * 2 - gap * 9) / 10
    out = []
    for r, row in enumerate(rows):
        y = top + pitch * r + (pitch - key_h) / 2
        out.append(f'<g id="row-{r + 1}">')
        if r == 2:
            side = unit * 1.35
            mid = row[1:-1]
            mid_w = unit * (1 if len(mid) == 7 else 1.42)
            span = mid_w * len(mid) + gap * (len(mid) - 1)
            out.append(key(inset, y, side, key_h, row[0], t, row[0]))
            x = (W - span) / 2
            for label in mid:
                out.append(key(x, y, mid_w, key_h, label, t, label))
                x += mid_w + gap
            out.append(key(W - inset - side, y, side, key_h, row[-1], t, row[-1]))
        else:
            span = unit * len(row) + gap * (len(row) - 1)
            x = (W - span) / 2
            for label in row:
                out.append(key(x, y, unit, key_h, label, t, label))
                x += unit + gap
        out.append("</g>")
    y = top + pitch * 3 + (pitch - key_h) / 2
    side, ret = unit * 1.35, unit * 2.75
    space_x = inset + side * 2 + gap * 2
    out.append('<g id="row-4">')
    out.append(key(inset, y, side, key_h, bottom_label, t, bottom_label))
    out.append(key(inset + side + gap, y, side, key_h, "emoji", t, "emoji"))
    out.append(key(space_x, y, W - inset - ret - gap - space_x, key_h, "", t, "space"))
    out.append(key(W - inset - ret, y, ret, key_h, "return", t, "return"))
    out.append("</g>")
    return "".join(out)


def top_bar(t, state):
    cy = 43
    out = ['<g id="top-bar">', f'<g id="menu-button">{icon("grid", 29, cy, t["label"], t["backdrop"])}</g>']
    area_x, third = 57, (W - 114) / 3
    if state == "recording":
        out.append('<g id="waveform">')
        levels = [4, 6, 9, 14, 20, 12, 7, 16, 24, 18, 10, 6, 13, 22, 26, 15, 8, 5, 11, 19, 23, 14, 9, 17,
                  25, 20, 12, 7, 5, 10, 16, 21, 13, 8, 6, 12, 18, 24, 16, 9, 6, 14, 20, 11, 7]
        for i, h in enumerate(levels):
            x = area_x + 6 + i * 5
            out.append(f'<rect x="{x}" y="{cy - h / 2}" width="3" height="{h}" rx="1.5" fill="{t["label"]}"/>')
        out.append("</g>")
        out.append(text(W - 57 - 4, cy, "0:07", 15, t["muted"], 500, "end"))
        out.append(f'<g id="voice-button"><circle cx="{W - 30}" cy="{cy}" r="18" fill="{RECORDING}"/>'
                   f'{icon("stop", W - 30, cy, "#FFFFFF", RECORDING)}</g>')
    else:
        words = ["the", "to", "and"] if state == "numbers" else ["The", "I", "And"]
        for i, word in enumerate(words):
            out.append(f'<g id="suggestion-{i + 1}">{text(area_x + third * (i + 0.5), cy, word, 18, t["muted"])}</g>')
        for i in (1, 2):
            out.append(f'<rect x="{area_x + third * i:.2f}" y="{cy - 16}" width="0.5" height="32" '
                       f'fill="{t["divider"]}" fill-opacity="{t["divider_opacity"]}"/>')
        out.append(f'<g id="voice-button"><circle cx="{W - 30}" cy="{cy}" r="18" fill="{t["voice"]}"/>'
                   f'{icon("waveform", W - 30, cy, t["voice_icon"], t["voice"])}</g>')
    out.append("</g>")
    return "".join(out)


def pills(t):
    inset, gap = 8, 8
    w = (W - inset * 2 - gap * 3) / 4
    out = ['<g id="action-pills">']
    for i, name in enumerate(["proofread", "paste", "search", "sparkles"]):
        x = inset + (w + gap) * i
        out.append(f'<g id="pill-{name}"><rect x="{x:.2f}" y="73" width="{w:.2f}" height="40" rx="20" '
                   f'fill="{t["key"]}"/>{icon(name, round(x + w / 2, 2), 93, t["label"], t["key"])}</g>')
    out.append("</g>")
    return "".join(out)


def frame(theme, state, x, y):
    t = THEMES[theme]
    total = H + STRIP
    out = [f'<g id="keyboard-{theme}-{state}" transform="translate({x} {y})">',
           f'<path id="system-backdrop" d="M0 28 a28 28 0 0 1 28 -28 h{W - 56} a28 28 0 0 1 28 28 v{total - 28} '
           f'h-{W} z" fill="{t["backdrop"]}"/>',
           top_bar(t, state), pills(t),
           key_rows(t, NUMBERS if state == "numbers" else LETTERS, "ABC" if state == "numbers" else "123"),
           f'<g id="system-strip">{icon("globe", 42, H + 31, t["label"], t["backdrop"])}'
           f'{icon("mic", W - 42, H + 31, t["label"], t["backdrop"])}</g>',
           "</g>"]
    return "".join(out)


def main():
    margin, label_h, gap_x, gap_y = 60, 40, 70, 70
    frames = [("dark", "letters", "dict8 — dark", "402 pt wide · keys 42.3 pt on a 54 pt pitch · gap 6 · radius 5.5"),
              ("dark", "recording", "Dictating", "live level meter and timer replace the suggestions; tap again to stop"),
              ("dark", "numbers", "Numbers page", "123 key; space returns to letters"),
              ("light", "letters", "dict8 — light", "follows the system appearance")]
    total = H + STRIP
    board_w = margin * 2 + W * 2 + gap_x
    board_h = margin * 2 + (label_h + total) * 2 + gap_y
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{board_w}" height="{board_h}" '
             f'viewBox="0 0 {board_w} {board_h}">', '<rect width="100%" height="100%" fill="#F5F5F7"/>']
    for i, (theme, state, title, sub) in enumerate(frames):
        x = margin + (i % 2) * (W + gap_x)
        y = margin + (i // 2) * (label_h + total + gap_y)
        parts.append(text(x, y + 6, title, 13, "#1C1C1E", 600, "start"))
        parts.append(text(x, y + 23, sub, 11, "#6C6C70", 400, "start"))
        parts.append(frame(theme, state, x, y + label_h))
    parts.append("</svg>")

    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "docs", "dict8-keyboard.figma.svg")
    with open(out, "w") as f:
        f.write("\n".join(parts))
    print(os.path.abspath(out), f"{board_w}x{board_h}")


if __name__ == "__main__":
    main()
