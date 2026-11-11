# FreeOrion Godot 4 client

Godot 4.4 and up based rewrite of the GiGi client, tries to be pixel precise as much as possible.

See `client/godot4/` for C++ GDExtension code.

`godot4/` is a work-in-progress Godot 4 rewrite of the FreeOrion client GUI.
The GDExtension bridge (`FreeOrionNode`) is available as the `GlobalFreeOrionNode`
autoload scene; the widgets are still hand-built from Godot containers and
theme style boxes that mimic the GG (GameGraphics) look.

Options are exposed by the `OptionsDB` engine singleton (`GodotOptionsDB` in
`client/godot4/`), registered during GDExtension scene initialization. It is not
a scene node and outlives `GlobalFreeOrionNode`, and GDScript can call it
directly as `OptionsDB.options_get_bool(...)`. `FreeOrionNode` keeps thin
forwarders (`GlobalFreeOrionNode.options_get_bool(...)`) so existing call sites
can be migrated separately. Option *values* are still loaded by
`FreeOrionNode._ready()` (`InitDirs`, config file, command line); before that
point only registry defaults are visible, and in the editor the singleton exists
but `_ready()` does not run.

The implemented screens are:

* the main menu (`IntroScreen`),
* the scrolling credits (`CreditsWnd`),
* the "Connect to Server" window (`ServerConnectWnd`),
* the map window with the Turn, Messages, SitRep, Empires, Objects, Research,
  Production, Ship Design, Government, Graphs, Pedia and menu toolbar buttons and
  the in-game menu (`MapWnd`).

The current branch is `godot4-next-ui`, rebased directly onto
`ae58c6f1620d0f905ec45bd0877db2a3f395feb1`.

## Files

| File | Purpose |
|---|---|
| `IntroScreen.tscn`, `IntroScreen.gd` | Main menu: splash/logo, parser and network threads, menu buttons, safe-area handling |
| `CreditsWnd.tscn`, `CreditsWnd.gd` | Scrolling credits read from `default/credits.xml` |
| `ServerConnectWnd.tscn`, `ServerConnectWnd.gd` | "Connect to Server" window: radio group, enable/disable rules, OK/Cancel |
| `MapWnd.tscn`, `MapWnd.gd` | Map window skeleton with the top toolbar (Turn plus the Messages, SitRep, Empires, Objects, Research, Production, Design, Government, Graphs, Pedia and menu icon buttons) and the in-game menu |
| `CUIButton.tscn`, `CUIButton.gd` | GG-style button scene: normal/hover/pressed/disabled styles, click and rollover sounds, `set_click_sound()` |
| `CUIIconButton.tscn`, `CUIIconButton.gd` | Icon-only `TextureButton` used by the toolbar: the icon textures are assigned per instance, `set_active()` swaps normal and hover while a window is open, plus the GG rollover/click sounds |
| `InGameMenu.tscn`, `InGameMenu.gd` | Modal in-game menu (Save, Load/Concede, Exit to Menu, Options, Done) shown over the map |
| `CUIRadioButton.gd` | `Button` subclass that draws GG-style radio circles + left-aligned caption |
| `CUIDropDown.gd` | `OptionButton` subclass that draws GG's bordered yellow arrow instead of the stock icon, styles the popup and removes its check marks |
| `CUIWindowFrame.gd` | Attached to the `WndOuter` panels; swaps the frame to `WndOuterFocus.tres` while the window or one of its children has focus and dims it again while a drop-down list is open |
| `assets/resources/EditNormal.tres`, `EditDisabled.tres` | Style boxes for `LineEdit` controls (GG `Edit`) |
| `assets/resources/EditFocus.tres` | `LineEdit` style while focused — GG lightens the edit border to 248 on focus (`CUIEdit::Render` uses `LightenClr`) |
| `assets/resources/ListNormal.tres`, `ListDisabled.tres` | Style boxes for the server list (GG `ListBox`) |
| `assets/resources/DropDownNormal.tres`, `DropDownDisabled.tres`, `DropDownFocus.tres` | Style boxes for the client-type drop-down (square top-left corner, GG does not cut it; `DropDownFocus.tres` keeps the bottom-right chamfer but lightens the border to 248) |
| `assets/resources/PopupPanel.tres`, `PopupHover.tres` | `OptionButton` popup: 1 px 124 border on a 15 background, and the 71 background Godot's `PopupMenu` draws for the focused row (GG's selected row) |
| `assets/resources/RadioStyle.tres` | Transparent button style used by the radio buttons (content margin leaves room for the circle) |
| `assets/resources/WndInnerTight.tres` | Thin inner panel frame (content margins 5/6/5/5 → ≈11 px inset like GG) |
| `assets/resources/WndOuter.tres`, `WndOuterFocus.tres` | Window frame, unfocused (64 border) and focused (128 border, GG's `LightenClr(64)`) |
| `android-plugin/` | Godot Android plugin, including `getRoundedCornerRadii()` and the server/AI services |
| `test/integration/test_quickstart.gd` | GUT test for the GDExtension bridge |
| `test/integration/test_options.gd` | GUT test for the `OptionsDB` engine singleton and the `FreeOrionNode` forwarders |

Existing shared resources are reused rather than duplicated: `WndOuter.tres`
(window frame), `ButtonNormal/Hover/Pressed/Disabled/Focus.tres` and the
`CUIButton.tscn` scene (which adds the GG click/rollover sounds and keeps the
label white when disabled, as GG's `TextControl` does).

## Main menu

`IntroScreen.gd` starts the parser and network threads and waits for
`parsing_completed` / `start_game` from `GlobalFreeOrionNode`.

* The splash and logo are chosen by date: April 1st, December 25th, October 31st
  and the "second == 42" Easter egg use alternative artwork.
* `content_scale_factor` is derived from `DisplayServer.screen_get_dpi()`:
  1.75 above 300 DPI, 1.35 above 200 DPI, otherwise 1.0.
* The bottom-right `Version` label is moved inside the display safe area and
  inside the rounded display corner; see [Android safe area and rounded
  corners](#android-safe-area-and-rounded-corners).
* *Multi Player* opens `ServerConnectWnd` inside the `Popup` panel, disables the
  menu button while the window is open and re-enables it when the window is
  cancelled or closed.
* *Credits* adds `CreditsWnd` as a child. *Quick Start* and *Exit* call
  `new_single_player_game()` and `get_tree().quit()`.
* When the game starts, `get_tree().change_scene_to_file("res://MapWnd.tscn")`
  switches to the map window.

## Credits window

`CreditsWnd` mirrors GG's credits screen:

* It darkens the middle band of the splash with a 50 % black `ColorRect` and
  scrolls a `RichTextLabel` upwards at 25 px/s (GG: ticks / 40).
* The visible band follows GG's `UPPER_LINE = 79` and `LOWER_LINE = 692` out of
  a 768 px splash, scaled to the current viewport height.
* `default/credits.xml` is read by the C++ bridge with
  `ReadFile(GetResourceDir() / "credits.xml")` and parsed with `XMLDoc`, so it
  also works on Android where `FileAccess` cannot reach the resource directory.
  `GlobalFreeOrionNode.get_credits()` returns the `GROUP`, `PERSON` and
  `RESOURCE` entries as dictionaries, which become centered BBCode; `[` is
  escaped as `[lb]` so names cannot inject tags.
* A left mouse click, `Escape`, a viewport resize, or the text scrolling past
  the top edge closes the window. `IntroScreen` passes `menu_left` so the text
  stays left of the main menu; the node frees itself on close.

## Connect to Server window

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

### GG look details

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

### Behaviour

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

### Text / i18n

All labels use GG stringtable keys as their literal text (`SCONNECT_WINDOW_TITLE`,
`PLAYER_NAME_LABEL`, `HOST_GAME_BN`, `JOIN_GAME_BN`, `LAN_GAME_LABEL`,
`INTERNET_GAME_LABEL`, `REFRESH_LIST_BN`, `OK`, `CANCEL`, `PLAYER`, `MODERATOR`,
`OBSERVER`). The translation is resolved through the GDExtension `GodotI18n`
bridge, so they render as the localized strings from `default/stringtables/`.

The scene root sets `auto_translate_mode = 1` so children translate automatically.
Nodes whose text is assigned manually at runtime (the `LineEdit`s and the radio
buttons) set `auto_translate_mode = 2`, otherwise `tr("")` would fall back to
`"ERROR: "`.

### Stubs / not implemented yet

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

## Multiplayer implementation plan

`ClientNetworking` already implements the transport (connect, disconnect, LAN
discovery, message queue, player/host IDs, auth roles). What is missing is the
Godot-facing layer, the multiplayer message handling, the client-side host/join
orchestration, and the lobby UI. The steps below are ordered so that each one
can be built and tested independently; keep the OK-button change and the
multiplayer plan in separate commits.

### Missing pieces at a glance

| Layer | Missing work |
|---|---|
| `FreeOrionNode` | Connection primitives, host/join/auth/lobby senders, and signals for handshake, lobby, chat, status, errors and disconnection |
| `FreeOrionNode::HandleMessage()` | Cases for `JOIN_GAME`, `HOST_MP_GAME`, `HOST_ID`, `AUTH_REQUEST`, `ERROR_MSG`, `LOBBY_UPDATE`, `LOBBY_EXIT`, `CHECKSUM`, `CHAT_HISTORY`, `PLAYER_CHAT`, `PLAYER_STATUS`, `END_GAME`, `PLAYER_INFO`, `TURN_TIMEOUT`, `UNREADY` |
| `GodotClientApp` | `HostMultiPlayerGame()`, `JoinMultiPlayerGame()`, cookie handling, server lifecycle, and honoring `network.server.external.force` |
| GDScript | OK result/persistence, LAN server list, client-type mapping, connection state, auth dialog, error handling |
| UI | A lobby window for both host and join, because the server always enters `MPLobby` before a game starts |
| Map | Multiplayer turn state (`PLAYER_STATUS`, `UNREADY`, `TURN_TIMEOUT`, `END_GAME`) |
| Android | Start/stop the server service for a multiplayer host and on client shutdown |
| Validation | Two-client host/join, external server, auth, LAN discovery, checksum mismatch, Android |

### 1. Expose connection primitives from `FreeOrionNode`

Bind these methods in `_bind_methods()` and implement them as thin wrappers
around `m_app->Networking()`:

```cpp
bool is_server_connected() const;                 // Networking().IsConnected()
bool connect_to_server(godot::String address, int timeout_ms = 10000);
void disconnect_from_server();                    // DisconnectFromServer()
godot::PackedStringArray discover_lan_servers();  // DiscoverLANServerNames()
```

`connect_to_server()` must keep the address so the later join request can use
`Networking().Destination()` for cookie lookup. `discover_lan_servers()` is
blocking; call it from the UI only via a worker thread or a deferred call so the
main thread does not freeze during the timeout.

### 2. Expose host/join/auth/lobby senders

Add methods that delegate to `GodotClientApp` rather than sending messages
directly, so the app can keep the connection state in one place:

```cpp
void host_game(godot::String player_name);
void join_game(godot::String player_name, int client_type);
void auth_response(godot::String player_name, godot::String password);
void send_lobby_chat(godot::String text, bool pm);
void start_mp_game();
void cancel_mp_game();
```

Map the GDScript client-type index (`0 = PLAYER`, `1 = MODERATOR`,
`2 = OBSERVER`) to `Networking::ClientType` in C++ and reject anything else.
`cancel_mp_game()` disconnects (the server removes the player on
`Disconnection`; there is no client-side lobby-exit message constructor); for a
host it must also free the local server.

### 3. Add multiplayer signals

Register the signals with `ADD_SIGNAL()` and emit them with `call_deferred()`
from the networking thread, as `start_game` already does:

| Signal | Payload |
|---|---|
| `auth_request` | `player_name`, `auth` |
| `join_game_ack` | `player_id` |
| `host_game_ack` | `host_player_id` |
| `host_id` | `player_id` |
| `lobby_update` | serialized lobby `Dictionary` |
| `lobby_exit` | none |
| `error` | `problem_key`, `unlocalized_info`, `fatal`, `player_id` |
| `player_status` | `empire_id`, `status` |
| `chat_message` | `text`, `player_name`, `text_color`, `pm`, `timestamp` |
| `chat_history` | `Array` of chat-entry `Dictionary`s |
| `player_info` | `Array` of player `Dictionary`s |
| `server_disconnected` | none |
| `checksum_mismatch` | none |
| `turn_timeout` | `seconds` |
| `turn_revoked` | none |

`MultiplayerLobbyData`, `PlayerInfo` and `ChatHistoryEntity` are C++ structs, so
serialize them into `godot::Dictionary`/`godot::Array` values: lobby data needs
`in_game`, `any_can_edit`, `start_lock_cause`, `save_game`,
`save_game_current_turn`, the galaxy setup fields and a `players` array; player
entries need `player_id`, `player_name`, `empire_name`, `empire_color`,
`client_type`, `player_ready` and `authenticated`; chat entries need
`player_name`, `text`, `text_color` and `timestamp`.

### 4. Handle the multiplayer messages

Extend `FreeOrionNode::HandleMessage()` with the following cases, mirroring
`GGHumanClientApp::HandleMessage()` and `HumanClientFSM`:

* `JOIN_GAME` — call `ExtractJoinAckMessageData()`; save a non-nil cookie under
  `network.known-servers._<address with . and : replaced by _>.cookie`, commit
  the options, set the player ID and emit `join_game_ack`.
* `HOST_MP_GAME` — parse `msg.Text()` as the host player ID, set both player and
  host IDs, send the logging config when this client is the host (add a
  `GodotClientApp::SendLoggingConfigToServer()` copied from GG), and emit
  `host_game_ack`.
* `HOST_ID` — set `HostPlayerID()` and emit `host_id`.
* `AUTH_REQUEST` — call `ExtractAuthRequestMessageData()` and emit
  `auth_request`; the dialog sends `AuthResponseMessage(player_name, password)`.
* `ERROR_MSG` — call `ExtractErrorMessageData()` and emit `error`. On a fatal
  error, disconnect, free a locally started server, and return to the intro
  screen.
* `LOBBY_UPDATE` — extract `MultiplayerLobbyData`, serialize it and emit
  `lobby_update`; `PLAYER_INFO` updates `m_app->Players()` and emits
  `player_info`.
* `LOBBY_EXIT` — emit `lobby_exit`.
* `CHECKSUM` — remember the message until `parsing_completed`; then call
  `m_app->VerifyCheckSum()` and emit `checksum_mismatch` on failure.
* `CHAT_HISTORY` / `PLAYER_CHAT` — extract and emit `chat_history` and
  `chat_message`; resolve the sender name and empire colour from
  `m_app->Players()` for in-game chat.
* `PLAYER_STATUS` — call `ExtractPlayerStatusMessageData()` and
  `m_app->SetEmpireStatus()`, then emit `player_status`.
* `TURN_TIMEOUT` — parse the remaining seconds and emit `turn_timeout`.
* `UNREADY` — emit `turn_revoked` so the map can switch the Turn button back to
  the "Revise" state.
* `END_GAME` — extract the reason, emit an error/status message, disconnect and
  free a locally started server.

### 5. Add host/join orchestration to `GodotClientApp`

Move the logic from `GGHumanClientApp::MultiPlayerGame()` into two public
methods:

```cpp
void HostMultiPlayerGame(const std::string& player_name);
void JoinMultiPlayerGame(const std::string& player_name,
                         Networking::ClientType client_type);
```

Host flow:

1. Refuse if `m_networking->IsConnected()`.
2. If `network.server.external.force` is **false**, set
   `m_single_player_game = false`, call `StartServer()`, call `FreeServer()`
   (GG starts the process and immediately relinquishes ownership), and use
   `localhost` as the destination. If it is **true**, skip starting a server and
   use `network.server.uri`.
3. `ConnectToServer(destination)`; on failure emit the connection-timeout error.
4. Send `HostMPGameMessage(player_name, DependencyVersions())`.

Join flow (the connection itself is made by `connect_to_server()`, so that
`Networking().Destination()` is already set):

1. Refuse if not connected.
2. Look up or create the per-server cookie options, parse the UUID and send
   `JoinGameMessage(player_name, client_type, DependencyVersions(), cookie)`.

Both flows must clear pending saves (`ClearPreviousPendingSaves`) and expose a
`ResetToIntro()`-style cleanup that disconnects, frees a locally started server,
clears player/host IDs and resets `m_single_player_game`.

`NewSinglePlayerGame()` currently ignores `network.server.external.force`; make
it use the same rule as GG while touching this code. `StartServer()` must add
`--singleplayer --skip-checksum` only for a single-player game — a multiplayer
host must not pass those flags.

### 6. Fill in the `ServerConnectWnd` OK result

* On `_ready()`, load `setup.multiplayer.player.name` and
  `setup.multiplayer.host.address` into the edits.
* Replace the print-only `_on_ok_pressed()` with a result object: player name,
  destination (`HOST GAME SELECTED` for host, otherwise the selected LAN row or
  the IP edit) and the client-type index.
* Persist the name and address with `OptionsDB.options_set_string()` and
  `OptionsDB.options_commit()` before emitting `ok_pressed`, so the next run
  starts with the previous values (GG does this in `OkClicked()`).
* Change `ok_pressed` to carry the three values, or expose them as read-only
  properties that `IntroScreen` reads after the signal.
* Keep the existing validation and Enter/Escape handling unchanged.

### 7. LAN discovery and server-list selection

Implement `_populate_server_list()` with the result of
`GlobalFreeOrionNode.discover_lan_servers()` and merge the servers stored under
`network.known-servers`. Each row must be selectable and must clear the IP edit
when selected; editing the IP must clear the list selection (GG's
`ServerSelected()` / `IPAddressEdited()`). Run discovery on *Refresh* and once
on open, without blocking the main thread. This also makes the existing
server-selection part of the OK rule reachable.

### 8. Wire the connection flow in `IntroScreen`

* On `ok_pressed`, disable the *Multi Player* button and start the host or join
  call.
* Host → `host_game(player_name)`; join → `connect_to_server(address)` then
  `join_game(player_name, client_type)`.
* Show progress/errors from the new signals. On `error` with `fatal = true`, or
  on a connection timeout, return to the intro screen and re-enable the button.
* Show an auth dialog with a password field on `auth_request` and call
  `auth_response(player_name, password)`.
* On `server_disconnected` or a fatal `END_GAME`, disconnect, free a hosted
  server and return to the intro screen.
* Leave the intro screen only when the game actually starts; for multiplayer
  that means opening the lobby window first (`lobby_update`), not changing
  directly to `MapWnd`.

### 9. Add a lobby window

The server enters `MPLobby` for both host and join, so even a join-only phase
needs a minimal lobby/waiting screen. A first version should provide:

* A player list from `lobby_update` (name, empire, type, ready/auth state).
* Galaxy settings from the lobby data; only the host may edit them.
* A chat log plus an input that calls `send_lobby_chat()`; append
  `chat_history` and `chat_message` entries.
* *Start* enabled only for the host and only when the lobby data allows it
  (`start_lock_cause` empty); it calls `start_mp_game()`, which sends
  `StartMPGameMessage()`.
* *Cancel* calls `cancel_mp_game()` and returns to the intro screen.
* Show `turn_progress` phases while the server generates the game; switch to
  `MapWnd` when `start_game` arrives.

### 10. Multiplayer turn state in `MapWnd`

* Handle `player_status` and keep per-empire `PLAYING_TURN`/`WAITING` state.
* Handle `turn_revoked` and `turn_timeout`: restore the Turn button to
  "Revise"/countdown behaviour and re-enable it when the server asks for orders
  again.
* Make sure `start_turn()` sends `TURN_ORDERS` and is valid for a non-host
  player; keep the existing `TURN_UPDATE` handling.
* Handle `END_GAME` by leaving the map and returning to the intro screen.

### 11. Android server lifecycle

* Use the existing plugin `startServer(args)` / `stopServer()`; a multiplayer
  host must start the service without `--singleplayer --skip-checksum`.
* `FreeServer()` must stop the service when the host cancels the lobby, the
  connection drops, or the game ends.
* `FreeOrionNode::_exit_tree()` currently stops only the threads. It must also
  disconnect and free/stop a server started by this client, otherwise the
  Android service can outlive the app.
* Verify the service keeps running while the lobby is open and while the game is
  being played on a device.

### 12. Validation

1. Rebuild the extension (`ninja libfreeoriongodot.so`) and run
   `gdformat -c`, `gdlint` and `git diff --check`.
2. Two desktop clients against one local server: host/join acks, lobby updates,
   chat, start, turn processing, disconnect.
3. External server with `network.server.external.force` / `network.server.uri`:
   no local process is started and the client connects to the configured URI.
4. Auth-protected server: `AUTH_REQUEST` → dialog → `AUTH_RESPONSE`, including a
   wrong password and a cancelled dialog.
5. LAN discovery and known-server lists, including selecting a row versus
   typing an address.
6. Checksum mismatch (modified content) shows `ERROR_CHECKSUM_MISMATCH` and does
   not start the game.
7. Android host/join on a device, including app exit with a hosted server.

## Map window and Turn button

`MapWnd.tscn` is a full-rect `Control` with a 42 px `ToolBar` panel across the
top, `ToolBar/BtnTurn` (a `CUIButton` instance) and the icon buttons
`ToolBar/BtnMessages`, `ToolBar/BtnSitRep`, `ToolBar/BtnEmpires`,
`ToolBar/BtnObjects`, `ToolBar/BtnResearch`, `ToolBar/BtnProduction`,
`ToolBar/BtnDesign`, `ToolBar/BtnGovernment`, `ToolBar/BtnGraphs`,
`ToolBar/BtnPedia` and `ToolBar/BtnMenu`:

* Scene offsets are `5, 8` to `116, 33` (25 px tall). The control expands to its
  text's minimum width, so the visible width depends on the current label.
* `MapWnd.gd` connects `GlobalFreeOrionNode.start_game` and `turn_update`, and
  installs `res://assets/sound/turn_button_click.ogg` through
  `CUIButton.set_click_sound()`; GG plays that sound on every successful turn
  click (`UI/MapWnd.cpp`, `PlayTurnButtonClickSound`).
* `_on_btn_turn_pressed()` calls `GlobalFreeOrionNode.start_turn()` and then
  refreshes the label.
* `_update_btn_turn()` disables the button while `get_current_turn() < 1` and
  otherwise sets `tr("MAP_BTN_TURN_UPDATE").replace("%1%", str(turn))`, i.e.
  "Turn %1%". GG shows `MAP_BTN_TURN_UNREADY` ("Revise %1%") only while a
  multiplayer turn is being revised; that branch is not implemented yet.
* The scene root uses `auto_translate_mode = 1`; `BtnTurn` uses
  `auto_translate_mode = 2` because its text is assigned in code.

### Toolbar icon buttons and the in-game menu

In GG (`UI/MapWnd.cpp`) the last eleven toolbar columns are the 32x32 icon
buttons `m_btn_messages` (`messages.png`, `messages_clicked.png`,
`messages_mouseover.png`), `m_btn_siterep` (`sitrep.png`, `sitrep_clicked.png`,
`sitrep_mouseover.png`), `m_btn_empires` (`empires.png`, `empires_clicked.png`,
`empires_mouseover.png`), `m_btn_objects` (`objects.png`, `objects_clicked.png`,
`objects_mouseover.png`), `m_btn_research` (`research.png`, `research_clicked.png`,
`research_mouseover.png`),
`m_btn_production` (`production.png`, `production_clicked.png`,
`production_mouseover.png`), `m_btn_design` (`design.png`, `design_clicked.png`,
`design_mouseover.png`),
`m_btn_government` (`government.png`, `government_clicked.png`,
`government_mouseover.png`), `m_btn_graphs` (`charts.png`, `charts_clicked.png`,
`charts_mouseover.png`), `m_btn_pedia` (`pedia.png`, `pedia_clicked.png`,
`pedia_mouseover.png`) and `m_btn_menu` (`menu.png`, `menu_clicked.png`,
`menu_mouseover.png`), in that order, separated by `LAYOUT_MARGIN` (5 px). GG
also has `m_btn_moderator` (`moderator.png`) in the column left of the messages
button; it is deliberately not implemented here because moderator actions are not
available to players or observers.
`MapWnd` has the matching `ToolBar/BtnMessages` … `ToolBar/BtnMenu` buttons; only
the menu button does something yet, and the in-game menu has *Done* wired while
the other actions stay disabled until the C++ calls listed under
[C++ actions behind the menu](#c-actions-behind-the-menu) exist.

`ShowMenu()` swaps the unpressed and rollover textures of `m_btn_menu` while the
modal `InGameMenu` is open so the icon looks active. The tooltips come from
`MAP_BTN_MENU` / `MAP_BTN_MENU_DESC` (the description is empty), and the
`ui.gamemenu` hotkey (F10 by default) opens the same menu.

#### Toolbar placement

`BtnTurn` is untouched and the icons are anchored to the right edge of the
toolbar (`anchor_left = anchor_right = 1.0`, `offset_top = 5`,
`offset_bottom = 37`), mirroring GG's column order:

```text
ToolBar (42 px tall, 1 px bottom border)
  BtnTurn       x = 5..116, y = 8..33   (not anchored)
  BtnMessages   offset_left = -407, offset_right = -375
  BtnSitRep     offset_left = -370, offset_right = -338
  BtnEmpires    offset_left = -333, offset_right = -301
  BtnObjects    offset_left = -296, offset_right = -264
  BtnResearch   offset_left = -259, offset_right = -227
  BtnProduction offset_left = -222, offset_right = -190
  BtnDesign     offset_left = -185, offset_right = -153
  BtnGovernment offset_left = -148, offset_right = -116
  BtnGraphs     offset_left = -111, offset_right = -79
  BtnPedia      offset_left = -74,  offset_right = -42
  BtnMenu       offset_left = -37,  offset_right = -5
```

Every icon is 32x32, which gives the same 5 px margin at the toolbar edge and the
same 5 px gap between the icons as GG's layout columns. The eleven controls span
402 px, so they need a toolbar at least about 523 px wide (402 px of icons plus the
5 px margin and `BtnTurn` up to x 116); narrower windows would make the icons
overlap `BtnTurn`, which is another reason to move the toolbar to an
`HBoxContainer` once the remaining columns are added. Using anchors avoids
converting the toolbar to a container for now and keeps the existing Android
left-edge shift in `_apply_safe_area()` independent. `MapWnd.gd` keeps the authored
offsets in `_icon_base_offsets`, keyed by node name, so every icon button can be
shifted by the same amount. Once the resource readouts and the moderator button are
added, replace the manual offsets with an `HBoxContainer` plus a right-aligned
spacer.

#### `CUIIconButton`

`CUIButton` is text-based, so icon-only toolbar buttons use
`CUIIconButton.tscn` / `CUIIconButton.gd`, a `TextureButton` with
`ignore_texture_size = true` and `stretch_mode = 0` (`STRETCH_SCALE`), which
scales the 64x64 GG icons into the control's 32x32 rect. `TextureButton` takes
its images from the `texture_normal` / `texture_hover` / `texture_pressed`
properties (not from theme icons), so the shared scene stays generic and every
instance in `MapWnd.tscn` assigns them:

```text
BtnMessages   texture_normal   = assets/art/icons/buttons/messages.png
              texture_hover    = messages_mouseover.png
              texture_pressed  = messages_clicked.png
              texture_disabled = messages.png
BtnSitRep     texture_normal   = assets/art/icons/buttons/sitrep.png
              texture_hover    = sitrep_mouseover.png
              texture_pressed  = sitrep_clicked.png
              texture_disabled = sitrep.png
BtnEmpires    texture_normal   = assets/art/icons/buttons/empires.png
              texture_hover    = empires_mouseover.png
              texture_pressed  = empires_clicked.png
              texture_disabled = empires.png
BtnObjects    texture_normal   = assets/art/icons/buttons/objects.png
              texture_hover    = objects_mouseover.png
              texture_pressed  = objects_clicked.png
              texture_disabled = objects.png
BtnResearch   texture_normal   = assets/art/icons/buttons/research.png
              texture_hover    = research_mouseover.png
              texture_pressed  = research_clicked.png
              texture_disabled = research.png
BtnProduction texture_normal   = assets/art/icons/buttons/production.png
              texture_hover    = production_mouseover.png
              texture_pressed  = production_clicked.png
              texture_disabled = production.png
BtnDesign     texture_normal   = assets/art/icons/buttons/design.png
              texture_hover    = design_mouseover.png
              texture_pressed  = design_clicked.png
              texture_disabled = design.png
BtnGovernment texture_normal   = assets/art/icons/buttons/government.png
              texture_hover    = government_mouseover.png
              texture_pressed  = government_clicked.png
              texture_disabled = government.png
BtnGraphs     texture_normal   = assets/art/icons/buttons/charts.png
              texture_hover    = charts_mouseover.png
              texture_pressed  = charts_clicked.png
              texture_disabled = charts.png
BtnPedia      texture_normal   = assets/art/icons/buttons/pedia.png
              texture_hover    = pedia_mouseover.png
              texture_pressed  = pedia_clicked.png
              texture_disabled = pedia.png
BtnMenu       texture_normal   = assets/art/icons/buttons/menu.png
              texture_hover    = menu_mouseover.png
              texture_pressed  = menu_clicked.png
              texture_disabled = menu.png
```

`set_active(true)` swaps normal and hover, which is how GG keeps the menu icon
highlighted while the menu is open, and `set_active(false)` restores it. The
scene carries the same `button_rollover.ogg` / `button_click.ogg` players as
`CUIButton.tscn`.

`MapWnd.gd` assigns the tooltips from the `TOOLBAR_ICON_BUTTONS` map as the raw
stringtable keys (`MAP_BTN_MESSAGES`, `MAP_BTN_SITREP`, `MAP_BTN_EMPIRES`,
`MAP_BTN_OBJECTS`, `MAP_BTN_RESEARCH`, `MAP_BTN_PRODUCTION`, `MAP_BTN_DESIGN`,
`MAP_BTN_GOVERNMENT`, `MAP_BTN_GRAPH`, `MAP_BTN_PEDIA`, `MAP_BTN_MENU`); GG's
`*_DESC` strings are empty, so a tooltip is just the button name. The keys are
deliberately not passed through `tr()`: the buttons inherit
`auto_translate_mode = 1` from the scene root and the tooltip label is translated
when it is shown, so translating a key twice makes `TranslationServer` look up
"Menu", which is not in the GG stringtable and renders as `ERROR: Menu`.

#### The `InGameMenu` window

`InGameMenu.tscn` / `InGameMenu.gd` is instantiated as a child of `MapWnd`, so
no scene change happens and the network thread keeps running:

* A full-rect backdrop `Control` with `mouse_filter = STOP` so clicks do not
  reach the map or the toolbar. The scene tree is not paused.
* The `Menu` `PanelContainer` uses `WndOuter` + `CUIWindowFrame.gd` and is
  centered with anchors, 200x270 px. `UI/InGameMenu.cpp` sizes the window as
  `ButtonWidth + 40` by `5.75 * ButtonCellHeight + 40` (160 + 40 by 230 + 40).
* `CUIWindowFrame.gd` gained `set_modal()`: a `GG::MODAL` window is the top
  window for as long as it runs, so the frame keeps the highlighted (128) border
  even though nothing inside has keyboard focus.
* A `WndInner` panel holds a `Control` of five `CUIButton`s, 160 px wide and
  placed in GG's cell grid (`Save` at y 6, `LoadOrConcede` at y 46,
  `ExitToMenu` at y 86, `Options` at y 121, `Done` at y 156). GG's buttons are
  24 px tall; Godot's `ButtonNormal.tres` margins make them 25 px, which
  reproduces the same 40 px cell pitch.
* Labels come from `GAME_MENU_WINDOW_TITLE`, `GAME_MENU_SAVE`,
  `GAME_MENU_LOAD` / `GAME_MENU_CONCEDE` (chosen by
  `GlobalFreeOrionNode.get_single_player_game()`), `GAME_MENU_RESIGN`,
  `INTRO_BTN_OPTIONS` and `DONE`, assigned with `tr()` in code because scene
  text is not translated here.
* *Done*, `Escape` and `Enter` close the window. `MapWnd._show_menu()` returns
  early when `_menu` is already set, matching GG's `ShowMenu()` guard.

#### Hotkey

`project.godot` defines the `ui_gamemenu` action with `Key(F10, None)`, and
`MapWnd._unhandled_input()` opens the menu when it is not already open. GG reads
the key from `OptionsDB` (`ui.gamemenu`); reading the GG keymap is a follow-up.

#### Messages, SitRep, Empires, Objects, Research, Production, Design,
Government, Graphs and Pedia buttons

`ToolBar/BtnMessages`, `ToolBar/BtnSitRep`, `ToolBar/BtnEmpires`,
`ToolBar/BtnObjects`, `ToolBar/BtnResearch`, `ToolBar/BtnProduction`,
`ToolBar/BtnDesign`, `ToolBar/BtnGovernment`, `ToolBar/BtnGraphs` and
`ToolBar/BtnPedia` are the icon buttons GG places in the columns left of the menu
button. All ten handlers are `pass` stubs, so clicking them only plays the GG click
sound for now:

* `MapWnd::ToggleMessages()` shows `ui.GetMessageWnd()`, restores the side panel and
  swaps the icon's unpressed/rollover graphics while the window is visible
  (`ShowMessages()` / `HideMessages()`). GG also hides the messages window when the
  production view mode is entered (`ui.production.mappanels.removed`).
* `MapWnd::ToggleSitRep()` shows `m_sitrep_panel` (the situation report overlaid on
  the map, `UI/SitRepPanel.cpp`) and keeps the icon highlighted while it is open;
  it is suppressed when Research, Production or Design is visible.
* `MapWnd::ToggleEmpires()` shows `ui.GetPlayerListWnd()` (the empires list,
  `UI/PlayerListWnd.cpp`) with the same highlight swap. GG does not hide it when the
  side panel is used, but the competing Research/Production/Design windows take
  precedence.
* `MapWnd::ToggleObjects()` shows `m_object_list_wnd` (`UI/ObjectListWnd.cpp`),
  hiding Research, Production, Design and the side panel first. The object list
  supports the filter text field and the "unexplored / all objects" mode
  (`m_object_list_mode`), which the Godot side has to reproduce later.
* `MapWnd::ToggleResearch()` shows `m_research_wnd`, hides the side panel and the
  competing Production and Design windows, honours `ui.research.pedia.hidden.enabled`
  and swaps the icon's unpressed/rollover graphics while the window is open.
  `HideResearch()` sends partial orders first.
* `MapWnd::ToggleProduction()` enters GG's production view mode: `ShowProduction()`
  hides Research, Design, the side panel and the Pedia panel, shows
  `m_production_wnd`, optionally removes the message and player-list windows
  (`ui.production.mappanels.removed`), sets `m_in_production_view_mode` and swaps
  the icon's unpressed/rollover graphics. `HideProduction()` sends partial orders
  and registers the windows again.
* `MapWnd::ToggleDesign()` shows `m_design_wnd` (`UI/DesignWnd.cpp`, created at
  the sub-window size) and, like `ShowMenu()`, swaps the unpressed and rollover
  graphics of the icon until that window is closed.
* `MapWnd::ToggleGovernment()` shows `m_government_wnd` (window name
  `map.government`, `UI/GovernmentWnd.cpp`) and does the same highlight swap.
  `HideGovernment()` also sends partial orders, and Government / Research /
  Production / Design windows hide one another, which the Godot side has to
  reproduce once the windows exist.
* `MapWnd::TogglePedia()` opens the encyclopedia side panel
  (`UI/EncyclopediaDetailPanel.cpp`), and `MapWnd::ShowGraphs()` opens the same
  panel with the `ENC_GRAPH` encyclopedia entry. Both need that side panel, which
  the Godot client does not have yet.
* GG registers the hotkeys `ui.map.messages` (Alt+T by default), `ui.map.sitrep`
  (Ctrl+N), `ui.map.empires` (Ctrl+E), `ui.map.objects` (Ctrl+O), `ui.research`
  (Ctrl+R), `ui.production` (Ctrl+P), `ui.design` (Ctrl+D), `ui.government`
  (Ctrl+I), `ui.pedia` (F1) and `ui.map.graphs`, which has no key bound by default
  (`GGK_NONE`, `HOTKEY_MAP_GRAPHS`). Adding these as `project.godot` input actions
  is a follow-up, together with reading the bindings from the GG `OptionsDB`.
* GG's `m_btn_graphs` is not a toggle: unlike the menu, messages, sitrep, empires,
  objects, research, production, design and government buttons it does not stay
  highlighted, so `set_active()` is currently used only by the menu icon and will be
  used by the other icons once their windows exist.

#### C++ actions behind the menu

`GodotClientApp` currently has none of the in-game menu actions. The bindings
needed (some can be follow-ups) are:

| GDScript call | `FreeOrionNode` | `GodotClientApp` |
|---|---|---|
| `can_save_now()` | wrapper | mirror `GGHumanClientApp::CanSaveNow()` |
| `save_game(filename)` | wrapper | `SaveGame()` with the pending-save queue |
| `load_game(filename)` | wrapper | `LoadSinglePlayerGame()` |
| `send_partial_orders()` | wrapper | inherited `ClientApp::SendPartialOrders()` |
| `resign()` | wrapper | disconnect, `FreeServer()`, reset client data |
| `concede()` | wrapper | send `EliminateSelfMessage()` |

Also add a `return_to_intro` signal (or reuse the existing disconnect/error
signals) so `MapWnd` can switch back to `IntroScreen` after *Exit to Menu* or a
server disconnect. `SendPartialOrders()` is public in `ClientApp`, so that part
is a thin wrapper.

* **Save Game**: open a `FileDialog` in save mode, check `can_save_now()`, then
  call `save_game(path)`. Add the `m_game_saves_in_progress` queue and
  `SAVE_GAME_COMPLETE` handling from GG.
* **Load Game**: single-player only; open a `FileDialog` in open mode and call
  `load_game(path)`. Changing scene happens through `start_game`, as with
  *Quick Start*.
* **Options**: there is no Godot options screen yet; keep the button disabled or
  hidden and document it as a follow-up instead of opening an empty window.
* **Exit to Menu** (`GAME_MENU_RESIGN`): send partial orders, disconnect, stop a
  locally hosted server, and return to `IntroScreen`.
* **Concede** (`GAME_MENU_CONCEDE`): show a confirmation dialog using
  `GAME_MENU_REALLY_CONCEDE`, send `ELIMINATE_SELF`, then close the menu. Disable
  it when the `RULE_ALLOW_CONCEDE` game rule is false, as GG does.
* **Done**: close the menu only; the game keeps running.

#### Right-edge safe area

`_apply_safe_area()` handles the icon buttons the same way it handles `BtnTurn`,
but mirrored: `_safe_area_right()` derives the inset from `safe.end.x` and the
window position, and `_top_right_corner_radius()` uses `getRoundedCornerRadii()[1]`
(the array is `[top-left, top-right, bottom-right, bottom-left]`).
`_icon_button_shift()` returns the clearance the icons need from the right edge
(the larger of the 5 px margin, the safe-area inset and the corner-arc value for
the buttons' top offset), and `offset_left` and `offset_right` of every icon button
are moved by it so they keep their 32 px width and the gaps between them.

#### Validation

Checked on X11 with the game binary (`--resolution 1280x720`, viewport
screenshots) and with a headless run of `MapWnd.tscn`:

* `BtnMessages` spans x 873..905, `BtnSitRep` x 910..942, `BtnEmpires`
  x 947..979, `BtnObjects` x 984..1016, `BtnResearch` x 1021..1053,
  `BtnProduction` x 1058..1090, `BtnDesign` x 1095..1127, `BtnGovernment`
  x 1132..1164, `BtnGraphs` x 1169..1201, `BtnPedia` x 1206..1238 and `BtnMenu`
  x 1243..1275 of the toolbar, all 32x32, 5 px from the right edge and 5 px apart;
  the ten gaps between them are empty and every cell contains glyph pixels (for
  example the envelope at x 876..901, y 12..31 and the sitrep triangle at
  x 912..939, y 7..34).
* The menu glyph is drawn at x 1248..1269, y 7..34, changes while the menu is
  open, and is byte-identical to the closed state after *Done*.
* Tooltips resolve to *Messages*, *Situation Report*, *Empires*, *Objects*,
  *Research*, *Production*, *Ship Design*, *Government Policies*, *Graphs*,
  *Pedia* and *Menu* through the GG stringtable, and the log has no
  `Missing string` entries.
* The menu panel is 200x270, its buttons are 160x25 in 40 px cells, the backdrop
  has `mouse_filter = STOP`, the modal frame uses the 128 border, only *Done* is
  enabled, and *Done* / `Escape` / `Enter` close the menu and restore the toolbar
  icon.
* `set_active(true)` on `BtnMessages` changes the pixels drawn in its cell and
  `set_active(false)` restores them exactly, so the highlight swap works for the
  newly added icons as well.

Not checked yet: the hover and pressed icon states on screen, the rollover and
click sounds, *Exit to Menu* returning to `IntroScreen` while a hosted server
keeps running, and the top-right safe area / rounded corner at Android DPI
scales. Note that `InGameMenu.gd` calls `get_single_player_game()`, so the
GDExtension has to be rebuilt for the menu to open with the shipped binary.

### Branch and UID notes

* Upstream added the map window in `128abbec1` ("Add BtnTurn to Godot4's
  MapWnd") and changed the click sound in `cb8e23c83`.
* During the rebase the branch's `MapWnd.gd.uid` was kept:
  `uid://2p2uyap4eaad`. Upstream's `MapWnd.tscn` references
  `uid://bhqrk7g1l6rwf`; the branch scene points at the retained branch UID
  instead.
* `MapWnd.gd` itself is upstream's version, because it already contains the
  click sound and `_on_btn_turn_pressed()`; `CUIButton.set_click_sound()` is
  required by it and is retained.
* `MapWnd.tscn` combines upstream's `pressed` connection with the experiment's
  `BtnTurn` geometry and initial `MAP_BTN_TURN_UPDATE` text.
* All other scene UIDs already matched upstream, so no further UID changes were
  needed.

## Android safe area and rounded corners

Android 12+ devices have rounded display corners, and many devices also have a
notch/cutout and system-bar insets. Because the map toolbar starts at the very
top-left of the window, the top-left corner arc can cover part of `BtnTurn`,
which sits at `(5, 8)`. The button must be shifted dynamically; a hard-coded
Android-only offset would be wrong on devices with a different corner radius or
on desktop.

The existing `IntroScreen.gd` already contains the needed pieces for the
bottom-right `Version` label:

```gdscript
var safe_area := DisplayServer.get_display_safe_area()
var window_size := DisplayServer.window_get_size()
var phys_margin_right := float(window_size.x - safe_area.end.x)
var phys_margin_bottom := float(window_size.y - safe_area.end.y)
var scale_factor := get_window().content_scale_factor
var logical_margin_x := phys_margin_right / scale_factor
var logical_margin_y := phys_margin_bottom / scale_factor
var phys_corner_margin := 0.0
if Engine.has_singleton("FreeOrion"):
    var plugin := Engine.get_singleton("FreeOrion")
    var radii: Array = plugin.getRoundedCornerRadii()
    phys_corner_margin = float(radii[2])  # bottom-right
var logical_corner_margin := phys_corner_margin / scale_factor
if logical_corner_margin > 0:
    logical_corner_margin = logical_corner_margin * (1.0 - sqrt(2.0) / 2.0)
var margin_x := maxf(logical_margin_x, logical_corner_margin)
var margin_y := maxf(logical_margin_y, logical_corner_margin)
$Version.offset_right = -margin_x
$Version.offset_bottom = -margin_y
```

The data sources are:

* `DisplayServer.get_display_safe_area()` — the unobscured rectangle in screen
  coordinates. `safe_area.end` gives the right/bottom insets;
  `safe_area.position` gives the left/top insets. Subtract
  `DisplayServer.window_get_position()` when the window may not be at `(0, 0)`.
* `DisplayServer.window_get_size()` — window size in physical pixels.
* `get_window().content_scale_factor` — the DPI scale set by `IntroScreen`
  (1.0 / 1.35 / 1.75); all safe-area and radius values are converted to
  logical/ui pixels by dividing by it.
* `Engine.get_singleton("FreeOrion").getRoundedCornerRadii()` — four radii in
  physical pixels in the order `[topLeft, topRight, bottomRight, bottomLeft]`
  (`FreeOrionPlugin.java`). Index `0` is the top-left corner needed by the Turn
  button; index `2` is the bottom-right one used by `Version`.

### Turn-button shift

Move only `BtnTurn`, not the toolbar: the toolbar is full-width and there is
plenty of free space to the right, while the toolbar is only 42 px tall and
shifting the button down by a full corner radius would push it out of the bar.

For the top-left corner of radius `r`, the rounded area is the rectangle minus
the quarter disk centred at `(r, r)`. The button is clear when its top-left
corner `(x0, y0)` satisfies:

```text
(x0 - r)^2 + (y0 - r)^2 >= r^2
```

If `y0 < r`, the smallest `x0` that clears the arc at the button's top edge is:

```text
x0_clear = r - sqrt(r^2 - (r - y0)^2)
```

so the horizontal shift is `max(0, x0_clear - x0)`. Any safe-area left inset is
used as a lower bound. The button's width is preserved.

`MapWnd.gd` stores the authored offsets once, then recomputes the target from
them on every call. That makes the calculation idempotent and lets a rotation
or a changed corner radius move the button back as well as forward:

```gdscript
var _turn_base_left := 0.0
var _turn_base_top := 0.0
var _turn_base_width := 0.0


func _ready() -> void:
	var btn: Button = $ToolBar/BtnTurn
	_turn_base_left = btn.offset_left
	_turn_base_top = btn.offset_top
	_turn_base_width = btn.offset_right - btn.offset_left
	...
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var btn: Button = $ToolBar/BtnTurn
	var radius := _top_left_corner_radius()
	var safe_left := _safe_area_left()
	var shift := _turn_button_shift(_turn_base_left, _turn_base_top, radius, safe_left)
	btn.offset_left = _turn_base_left + shift
	btn.offset_right = btn.offset_left + _turn_base_width


func _safe_area_left() -> float:
	if OS.get_name() != "Android":
		return 0.0
	var scale: float = get_window().content_scale_factor
	var safe := DisplayServer.get_display_safe_area()
	var window_pos := DisplayServer.window_get_position()
	return maxf(float(safe.position.x - window_pos.x), 0.0) / scale


func _top_left_corner_radius() -> float:
	if OS.get_name() != "Android" or not Engine.has_singleton("FreeOrion"):
		return 0.0
	var radii: Array = Engine.get_singleton("FreeOrion").getRoundedCornerRadii()
	return maxf(float(radii[0]) / get_window().content_scale_factor, 0.0)


func _turn_button_shift(base_left: float, top: float, radius: float, safe_left: float) -> float:
	var target_left := maxf(base_left, safe_left)
	if radius > 0.0 and top < radius:
		target_left = maxf(
			target_left, radius - sqrt(radius * radius - (radius - top) * (radius - top))
		)
	return target_left - base_left
```

Why this is enough:

* On desktop, both `_safe_area_left()` and `_top_left_corner_radius()` return
  `0`, so `_apply_safe_area()` restores the authored offsets exactly.
* On Android the radii are physical pixels, so they are divided by
  `content_scale_factor` before being compared with the logical UI offsets.
* With a typical logical radius of 40 and `top = 8`, the formula moves the
  button from `x = 5` to `x = 16`; it does not over-shift by the full radius.
* With a logical radius of 60 the button moves to `x ≈ 30`. A safe-area left
  inset of 24 moves it to `x = 24` even when the corner radius is `0`.
* If the device reports no rounded corner (`0`) or an older Android version,
  `getRoundedCornerRadii()` returns zeros and only the safe-area left inset is
  applied.
* The entire toolbar is still clipped by the physical corner, but the button
  label and hit area are no longer cut.

If the toolbar later gets more controls, apply the same computed margin to a
container (`MarginContainer`/`HBoxContainer`) instead of to one button. For a
right-aligned control use `radii[1]` (`topRight`) and reduce `offset_right`
instead of increasing `offset_left`; for bottom corners use `radii[2]` /
`radii[3]` and adjust the bottom offsets. A vertical safe-area inset (status
bar or cutout) should be handled by moving or growing the whole `ToolBar`, not
by moving `BtnTurn` down inside a 42 px bar.

### Virtual keyboard covering the address edit

Android does not shrink Godot's viewport when the IME opens; the keyboard is
drawn over the bottom of the client area. The address `IPEdit` is near the
bottom of the centered `ServerConnectWnd` popup, so without help the keyboard
covers both the edit and the OK/Cancel row.

Godot exposes the IME height through
`DisplayServer.virtual_keyboard_get_height()`. The value is in physical pixels
and is `0` while the keyboard is hidden, so it must be divided by
`get_window().content_scale_factor` before it is compared with UI coordinates.
`IntroScreen.gd` polls it in `_process()` while the popup is visible and moves
the whole `Popup` `PanelContainer`:

```gdscript
const KEYBOARD_MARGIN := 8.0


func _process(_delta: float) -> void:
	if $Popup.visible:
		_keep_popup_above_keyboard()


func _keep_popup_above_keyboard() -> void:
	var popup: Control = $Popup
	var keyboard_height := _virtual_keyboard_height()
	popup.position.y = _popup_target_y(popup, keyboard_height)


func _virtual_keyboard_height() -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var physical_height := DisplayServer.virtual_keyboard_get_height()
	if physical_height <= 0:
		return 0.0
	return float(physical_height) / get_window().content_scale_factor


func _popup_target_y(popup: Control, keyboard_height: float) -> float:
	var viewport_height := get_viewport_rect().size.y
	var centered_y := (viewport_height - popup.size.y) * 0.5
	if keyboard_height <= 0.0:
		return centered_y

	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not popup.is_ancestor_of(focus):
		return centered_y

	var focus_bottom := focus.get_global_rect().end.y - popup.get_global_rect().position.y
	var keyboard_top := viewport_height - keyboard_height
	var target_bottom := centered_y + focus_bottom
	if focus_bottom > popup.size.y * 0.5:
		# When editing the address (or another lower field), keep the whole
		# window including the OK/Cancel row above the keyboard.
		target_bottom = centered_y + popup.size.y
	var shift := maxf(0.0, target_bottom + KEYBOARD_MARGIN - keyboard_top)
	return centered_y - shift
```

The logic is deliberately focus-dependent:

* The popup normally stays at its centered position, exactly as on desktop.
* When the focused field is in the lower half (the address edit), the popup
  moves up just enough to keep its bottom edge — including OK/Cancel — above the
  keyboard.
* When the focused field is in the upper half (the player name), it moves only
  if that field itself would be covered, so the title and name stay visible.
* The global rect is measured relative to the popup, so repeated `_process()`
  calls during the IME animation do not accumulate an offset. When the keyboard
  hides, the height becomes `0` and the popup returns to the centered position.

On desktop the virtual-keyboard feature is absent (or the height is `0`), so the
whole path is a no-op. This is preferred over an Android manifest
`windowSoftInputMode="adjustResize"` workaround: FreeOrion runs with
`screen/immersive_mode=true`, and whether Android resizes, pans or leaves the
surface alone depends on the OS version and the export template. Moving the
popup works consistently and keeps the fixed GG window layout. Wrapping the
window in a `ScrollContainer` and calling `ensure_control_visible()` is another
valid approach, but it would restructure the window and add a scrollbar to a
layout that is supposed to match GG.

## Validation

The branch was checked with:

```sh
find godot4/ -iname '*.gd' -not -path 'godot4/addons/gut/*' | xargs gdformat -c
find godot4/ -iname '*.gd' -not -path 'godot4/addons/gut/*' | xargs gdlint
git diff --check ae58c6f16 HEAD
```

All ten non-GUT scripts are formatter- and linter-clean.

A headless/runtime probe with
`Godot_v4.4.1-stable_linux.x86_64 --path godot4` verified:

* `uid://2p2uyap4eaad` is registered and `MapWnd` loads through
  `res://MapWnd.gd`.
* The intro screen loads, the Credits button is enabled, the credits window
  parses 11 520 characters and frees itself on close.
* The server window is `399x532`, `NameEdit` takes focus and the frame uses
  `WndOuterFocus.tres`. Typing a key no longer errors, OK becomes enabled for
  `Alice`, and `Enter` prints `name=Alice type=PLAYER host=localhost`, closes the
  popup and re-enables *Multi Player*.
* `BtnTurn` is created at `(5, 8)`, 25 px tall, with text
  `MAP_BTN_TURN_UPDATE`, the `turn_button_click.ogg` click stream and the
  `pressed` connection present.
* Simulating the Android corner shift on the loaded `MapWnd` moves the Turn
  button from `x = 5` to `x = 16` for a 40 px logical radius and to
  `x ≈ 30.1` for 60 px; a 24 px safe-area left inset moves it to `x = 24`.
  Re-running the desktop calculation restores the authored `x = 5`.
* On desktop the server popup stays centered at `(440.5, 134)`. Simulating a
  250 px keyboard with the address edit focused moves it to `y = 10`; both the
  address edit and the popup bottom (OK/Cancel) end up above the simulated
  keyboard top at `y = 550`. Hiding the keyboard returns it to `y = 134`.

The `godot4/.godot/` class cache is not committed. If the project is opened
after adding new `class_name` scripts, regenerate it once with
`--headless --editor --quit`; otherwise Godot may report `Could not find type`
for `CUIDropDown`, `CreditsWnd` and similar classes.

## Running it

```sh
Godot_v4.4.1-stable_linux.x86_64 --path godot4 res://IntroScreen.tscn
```

Then click *Multi Player* to open the server window, or start a game to reach
`MapWnd`. `godot4/test/integration/` contains GUT tests for the GDExtension
bridge and the `OptionsDB` singleton (run with GUT); the UI itself has no tests
yet.
