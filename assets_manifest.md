# Assets Manifest - Rule Glyph Lab

This document lists all non-code asset resources utilized in **Rule Glyph Lab** to ensure 100% compliance with clean-room guidelines and permissive licensing (MIT/CC0).

## Summary of Assets
* All visual game assets (player icon, glyph icons, portals, keys, pressure plates, doors) are rendered **procedurally** using CSS styling, inline SVGs, or dynamic HTML5 structures. No external images are fetched or loaded.
* All audio effects (moves, rules toggles, wins, losses, merges, unlocks) are generated **procedurally** in real-time using the browser's **Web Audio API** oscillator and gain nodes. No external audio files are loaded.
* All fonts are loaded dynamically from Google Fonts (open-source Open Font License - OFL).

## Assets Table

| Asset Name | Source Path | Original Author / License | Description |
| :--- | :--- | :--- | :--- |
| **Share Tech Mono Font** | Google Fonts | Open Font License (OFL) | Cybernetic style typography for UI. |
| **Orbitron Font** | Google Fonts | Open Font License (OFL) | Sci-fi header font. |
| **Procedural Audio FX** | Synthesized in `js/audio.js` | Built-in / CC0 | Retro synthesizers for moves, rule changes, merges, portal entry. |
| **Dynamic Vectors & SVGs** | Inlined in `index.html` & `js/grid.js` | Built-in / CC0 | Vector icons representing Glyphs (Alpha, Beta, Gamma), Portal, Spikes, and Doors. |

All assets are 100% free of copyleft restrictions and completely legal for closed-source or open-source distribution.
