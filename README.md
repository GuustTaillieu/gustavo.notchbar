# Notch Island

A dynamic, floating **Notch & Dynamic-Island** status bar for **[Omarchy](https://github.com/basecamp/omarchy)** built with Quickshell and Qt Quick.

Designed with smooth organic fillet curves that visually anchor the bar to the top of your display, featuring interactive dynamic expansion, edge snapping, rich media controls, keybind helpers, application launcher, and smart fullscreen overlay auto-reveal.

---

## ✨ Features

- **🏝️ Dynamic Notch Aesthetic**: Smooth concave bezel fillet arcs flaring naturally into the display edges.
- **⚡ Interactive Center Dynamic Island**:
  - **Idle Clock & Date**: Clean compact clock that smoothly animates and morphs into active states.
  - **App Search & Launcher**: Fast app launcher with fuzzy finding.
  - **Keybinds Cheatsheet**: Quick interactive search for Hyprland shortcuts and keybindings.
  - **Media Player Pill**: Live MPRIS player with album thumbnail, track metadata, and interactive playback controls.
  - **Volume & Brightness OSDs**: Dynamic slider feedback for sound and screen adjustments.
- **🎬 Smart Fullscreen Auto-Slide**:
  - Automatically hides the center island during fullscreen videos or gaming sessions.
  - Smoothly slides down from the top bezel when a notification arrives or volume changes, then slides back up after timeout.
- **🖐️ Right-Click & Drag Islands**:
  - Right-click and drag anywhere on any widget or notch surface to freely reposition Left, Center, or Right islands across your screen.
  - Visual two-way horizontal arrow cursor (`↔`) feedback during dragging.
  - Collision-safe repositioning that automatically saves your island layout persistently across reboots.
- **🧲 Edge Wall Snapping & Adaptive Resizing**:
  - Dragging islands against the screen bezels snaps them into corner-attached mode with outward flaring fillets.
  - Attached islands resize inward into the screen, ensuring widgets never overflow beyond display borders.
- **🎨 Style Presets (`edge` vs `island`)**:
  - Easily toggle or switch between Corner-Attached (`edge`) and Floating Notches (`island`) with the included `omarchy-notchbar-style` CLI tool or shell IPC.
- **📐 Compact Window Spacing**:
  - Optimized layer-shell exclusive zones so tiled and floating windows sit tight and close under the bar with no wasted screen real estate.
- **🖱️ System Tray Integration**:
  - Dynamic collapsing tray drawer that only consumes space for visible items and smoothly expands on hover. Quick right-clicking opens background app menus seamlessly.

---

## 🚀 Installation

Install directly with the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/GuustTaillieu/gustavo.notchbar.git
```

Or clone into your plugins directory:

```bash
git clone https://github.com/GuustTaillieu/gustavo.notchbar.git ~/.config/omarchy/plugins/gustavo.notchbar
omarchy-shell shell rescanPlugins
```

### Activate the Bar

Set `gustavo.notchbar` as your active bar in `~/.config/omarchy/shell.json`:

```json
{
  "version": 1,
  "bar": {
    "id": "gustavo.notchbar"
  }
}
```

Or switch to it dynamically:

```bash
omarchy bar set gustavo.notchbar
omarchy restart shell
```

---

## 🕹️ Controls & Interactions

### Island Dragging & Positioning
| Action | Gesture | Description |
|---|---|---|
| **Move Island** | `Right-Click + Drag` on any widget or notch | Drag Left, Center, or Right islands anywhere along the top edge |
| **Snap to Edge** | Drag near screen left/right border | Snaps into edge-attached mode with smooth bezel fillets |
| **Reorder Widgets** | `Left-Click + Drag` on a widget | Move and reorder widgets within islands or across different zones |
| **Widget Context Menu** | `Right-Click` (tap without drag) | Opens widget context menus (e.g., System Tray background app menus) |

### Center Island Shortcuts
| Shortcut / Action | What it does |
|---|---|
| `SUPER + SPACE` | Toggle Application Launcher / Search modal |
| `SUPER + ALT + SPACE` | Open Apps Menu |
| `SUPER + SHIFT + K` / `SUPER + CTRL + K` | Open Keybindings & Shortcuts Cheatsheet |
| `Left-Click` on Clock | Open expanded Date & Calendar view |

---

## 🎨 Style Switcher CLI

The plugin includes a helper script `omarchy-notchbar-style` to switch between island layouts on the fly:

```bash
# Toggle between corner-attached and floating styles
./omarchy-notchbar-style toggle

# Stick left and right islands to the screen corners
./omarchy-notchbar-style edge

# Float all three islands with dual top arcs
./omarchy-notchbar-style island
```

You can also trigger these styles directly via IPC from any script or hotkey:

```bash
omarchy-shell island style edge
omarchy-shell island style island
omarchy-shell island style toggle
```

---

## ⚙️ Customization & Layout

You can customize widgets inside `~/.config/omarchy/shell.json`.

Example configuration:

```json
{
  "version": 1,
  "bar": {
    "id": "gustavo.notchbar",
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "omarchy.workspaces" }
      ],
      "center": [
        { "id": "omarchy.clock" }
      ],
      "right": [
        { "id": "omarchy.tray" },
        { "id": "omarchy.audio" },
        { "id": "omarchy.power" }
      ]
    }
  }
}
```

---

## 🧩 Plugin Structure

```
gustavo.notchbar/
├── Bar.qml                 # Main Layer-Shell PanelWindow orchestration & drag engine
├── CenterIsland.qml        # Interactive dynamic notch & multi-mode morphing island
├── NotchSurface.qml        # Procedural SVG-fillet concave curve renderer
├── NotchSearchOverlay.qml  # Fullscreen search scrim & modal launcher
├── LeftIsland.qml          # Left island component
├── MenuModel.js            # App search, launcher, and keybind data loader
├── omarchy-notchbar-style  # CLI script for switching island styles
├── manifest.json           # Omarchy plugin manifest
├── widgets/                # First-party widget delegates (Tray, etc.)
├── LICENSE                 # License file
└── README.md               # Documentation
```

---

## 📄 License

MIT License. Designed and built for the Omarchy community.
