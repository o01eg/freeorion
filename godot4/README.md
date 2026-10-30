# FreeOrion Godot 4 client

`godot4/` is a work-in-progress Godot 4 rewrite of the FreeOrion client GUI.
The GDExtension bridge (`FreeOrionNode`) is available as the `GlobalFreeOrionNode`
autoload scene; the widgets are still hand-built from Godot containers and
theme style boxes that mimic the GG (GameGraphics) look.

This document describes the current state of the **"Connect to Server"**
window (`ServerConnectWnd`), which is the most recently implemented screen.

## Files

| File | Purpose |
|---|---|
| `ServerConnectWnd.tscn` | Scene for the "Connect to Server" window |
| `ServerConnectWnd.gd` | Behaviour: radio group, enable/disable rules, OK/Cancel |
| `CUIRadioButton.gd` | `Button` subclass that draws GG-style radio circles + left-aligned caption |
| `CUIDropDown.gd` | `OptionButton` subclass that draws GG's bordered yellow arrow instead of the stock icon, styles the popup and removes its check marks |
| `assets/resources/EditNormal.tres`, `EditDisabled.tres` | Style boxes for `LineEdit` controls (GG `Edit`) |
| `assets/resources/EditFocus.tres` | `LineEdit` style while focused — GG lightens the edit border to 248 on focus (`CUIEdit::Render` uses `LightenClr`) |
| `assets/resources/ListNormal.tres`, `ListDisabled.tres` | Style boxes for the server list (GG `ListBox`) |
| `assets/resources/DropDownNormal.tres`, `DropDownDisabled.tres`, `DropDownFocus.tres` | Style boxes for the client-type drop-down (square top-left corner, GG does not cut it; `DropDownFocus.tres` keeps the bottom-right chamfer but lightens the border to 248) |
| `assets/resources/PopupPanel.tres`, `PopupHover.tres` | `OptionButton` popup: 1 px 124 border on a 15 background, and the 71 background Godot's `PopupMenu` draws for the focused row (GG's selected row) |
| `assets/resources/RadioStyle.tres` | Transparent button style used by the radio buttons (content margin leaves room for the circle) |
| `assets/resources/WndInnerTight.tres` | Thin inner panel frame (content margins 5/6/5/5 → ≈11 px inset like GG) |
| `assets/resources/WndOuter.tres`, `WndOuterFocus.tres` | Window frame, unfocused (64 border) and focused (128 border, GG's `LightenClr(64)`) |
| `CUIWindowFrame.gd` | Attached to the `WndOuter` panels; swaps the frame to `WndOuterFocus.tres` while the window or one of its children has focus and dims it again while a drop-down list is open |
| `IntroScreen.gd` | Opens the window from the *Multi Player* menu entry and closes it again |

Existing shared resources are reused rather than duplicated: `WndOuter.tres`
(window frame), `ButtonNormal/Hover/Pressed/Disabled/Focus.tres` and the
`CUIButton.tscn` scene (which adds the GG click/rollover sounds and keeps the
label white when disabled, as GG's `TextControl` does).

## Layout

The window is built with containers only (no absolute positioning), mirroring the
menu in `IntroScreen.tscn`: a `PanelContainer` with the `WndOuter` style holds the
window, and its child is a `VBoxContainer` (`ServerConnectWnd.tscn`) with the title
label plus an inner `PanelContainer` using the `WndInnerTight` style.

Approximate mapping to the GG layout (`UI/ServerConnectWnd.cpp`, window 400x535):

| GG control | Godot node | Notes |
|---|---|---|
| window 400x535 | `ServerConnectWnd` `custom_minimum_size` 387x521 inside `WndOuter` | rendered popup is ~399x532; content starts 11 px inside the frame like GG |
| title `SCONNECT_WINDOW_TITLE` | `Title` `Label` | |
| player name label + edit | `NameRow` (`HBoxContainer`) with `NameLabel` (min width 90) and `NameEdit` (`LineEdit`, height 30) | |
| host/join radio group | `ModeRow` → `RadioGroup` (`VBoxContainer`, min width 165) with `Host` / `Join` `CUIRadioButton`s (24 px tall) | GG circle is the 16 px font point size |
| client type drop-down | `ModeRow` → `ClientTypeBox` with a 29 px spacer and `ClientType` (`CUIDropDown`, 205x23) | GG `DropDownList` (209x23), bottom-aligned with the radio group |
| `LAN_GAME_LABEL` | `LanLabel` | |
| server list 379x243 | `ServerList` (`PanelContainer`, min height 242, `size_flags_vertical = 3`) containing `List` (`VBoxContainer`) | |
| `REFRESH_LIST_BN` 101x24 | `RefreshRow` with expanding spacer + `Refresh` (`CUIButton`, 100x25) | right aligned |
| `INTERNET_GAME_LABEL` | `InternetLabel` | |
| IP address edit | `IPEdit` (`LineEdit`, height 30, default text `localhost`) | |
| OK / Cancel 100x27 | `OkCancelRow` with expanding spacer + `Ok` and `Cancel` (`CUIButton`, 100x28) | right aligned |

## GG look details

Verified pixel-by-pixel against GG screenshots and the GG source:

* **Window frame**: GG's `CUIWnd::Render` draws the outer border in
  `WndOuterBorderColor` (64) and lightens it to `LightenClr(64)` = 128 while the
  window — or a child of it — has focus. `CUIWindowFrame.gd` reproduces that:
  every `WndOuter` panel starts dim (64) and brightens (128) on
  `gui_focus_changed`. A drop-down list is a separate window in GG, so the
  frame dims again while the popup is open. The inner frame border is always
  192 (`WndInnerBorderColor`).
* **Inner frame placement**: the inner panel fills the frame height and stops
  4 px above the outer border at the bottom (GG `BORDER_BOTTOM = 5`, i.e. 4
  background rows between the two 1 px lines), instead of floating above it.
* **Controls inset**: content sits ~11 px inside the window border (GG: inner
  panel border + 6 px margins).
* **Radio buttons**: 16 px circle (the UI font point size), 1 px border in
  `CtrlBorderColor` 124; unchecked interior rings 89/49, checked
  `(50,177,50)`/`(0,127,0)`; hover brightens border/fill. Caption starts at 24 px
  (GG `DoLayout` spacing = `BN_W * 1.5`) and is vertically centered on the circle.
* **Edits**: unfocused border 124, **focused border 248** (`LightenClr(124)`) —
  GG lightens the border while the edit has focus, so `EditFocus.tres` is used
  for the `focus` state. Disabled edits: interior 99, border 126.
* **Buttons**: enabled 15 bg / 124 border, hover border 224, pressed 40 bg,
  disabled 99 bg / 126 border; the label stays **white** when disabled (GG's
  `TextControl` always draws `TextColor`), hence
  `font_disabled_color = white` on `CUIButton.tscn`.
* **Drop-down**: GG draws a 20x17 bordered box with a 11x11 yellow triangle
  (fill `(130,130,0)`, outline `(205,205,75)`) instead of an arrow icon.
  `CUIDropDown.gd` generates that image at runtime and replaces the theme `arrow`
  icon. The top-left corner of the control stays square (GG does not cut it);
  the bottom-right corner of the control **and of the arrow box** is chamfered
  (`CUIDROPDOWNLIST_ANGLE_OFFSET`). The arrow box border follows the control
  state: 124 normally, 127 disabled, 248 while the drop-down has focus
  (`update_arrow()` regenerates the texture, since it is an `ImageTexture`).
  The drop-down text stays **white** when disabled (GG's `TextControl`), hence
  `font_disabled_color = white` in `ServerConnectWnd.tscn`.
* **Drop-down popup**: the popup has a 1 px 124 border over a 15 background and
  paints the selected row with the GG list-selection colour 71 while the text
  stays white. Godot's `PopupMenu` has no per-item background colour API, so the
  `hover` style box (71) is used instead: the focused row is moved onto the
  selected item on open and whenever the mouse leaves the list, and removed
  while the mouse hovers another row. GG rows have no check marks, so
  `uncheck_rows()` turns off the radio flags of Godot's popup rows.
* **Drop-down focus**: while the popup is open the control border stays 124
  (GG's list is a separate window); after it closes `CUIDropDown.gd` calls
  `grab_focus()` and swaps in `DropDownFocus.tres`, so the border — including
  the arrow box — lights up to 248 exactly like GG's focused screenshot.

## Behaviour

`ServerConnectWnd.gd` mirrors `ServerConnectWnd::EnableDisableControls()`:

* `Host a new game` selected (default): client type drop-down, LAN label, server
  list, *Refresh list* and the IP address edit are disabled (GG grey styles);
  OK stays disabled until the player name is valid.
* `Join a game as` selected: those controls become enabled.
* OK is enabled when the name passes `NameOK()` (`^[A-Za-z0-9_-]+$`, implemented
  as a character check in `_name_ok()`) **and** either a server is selected or an
  IP address is entered.
* `Enter` triggers OK, `Escape` triggers Cancel, like GG.
* On open the player name edit takes focus, mirroring
  `ServerConnectWnd::ModalInit()`, which also gives the window its highlighted
  outer border.
* The window emits `ok_pressed` / `cancel_pressed`; `IntroScreen.gd` frees the
  window, hides the popup, re-enables the *Multi Player* button and returns the
  focus to it (so the main menu frame lights up again).

## Text / i18n

All labels use GG stringtable keys as their literal text (`SCONNECT_WINDOW_TITLE`,
`PLAYER_NAME_LABEL`, `HOST_GAME_BN`, `JOIN_GAME_BN`, `LAN_GAME_LABEL`,
`INTERNET_GAME_LABEL`, `REFRESH_LIST_BN`, `OK`, `CANCEL`, `PLAYER`, `MODERATOR`,
`OBSERVER`). The translation is resolved through the GDExtension `GodotI18n`
bridge, so they render as the localized strings from `default/stringtables/`.

The scene root sets `auto_translate_mode = 1` so children translate automatically.
Nodes whose text is assigned manually at runtime (the `LineEdit`s and the radio
buttons) set `auto_translate_mode = 2`, otherwise `tr("")` would fall back to
`"ERROR: "`.

## Stubs / not implemented yet

* No networking: `_populate_server_list()` is an empty stub (GG runs LAN
  discovery plus the `network.known-servers` options here), so the list is always
  empty and the server-selection part of the OK rule never fires.
* The player name is not read from / written to `setup.multiplayer.player.name`
  and the address is not stored in `setup.multiplayer.host.address`.
* OK only prints the chosen values and closes the window; no connection is made.
* The client type drop-down has no effect beyond being enabled/disabled.
* The server list has no scrolling, selection or row highlighting yet.
* Radio buttons do not play the GG click/rollover sounds (`CUIButton.tscn` is not
  used for them).

## Running it

```sh
Godot_v4.4.1-stable_linux.x86_64 --path godot4 res://IntroScreen.tscn
```

Then click *Multi Player* to open the window. `godot4/test/integration/` contains
GUT tests for the GDExtension bridge (run with GUT); the UI itself has no tests
yet.
