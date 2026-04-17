# Anti Double-Click

Tiny Windows tray utility that filters mouse "chatter" — extra clicks emitted by a worn-out switch. Any mouse-button press arriving within `threshold` milliseconds of the previous press on the same button is dropped before reaching the OS.

## Download

Grab the latest portable `AntiDoubleClick.exe` from the [Releases page](https://github.com/raihank43/AntiDoubleClick/releases/latest). No installer, no dependencies — double-click to run.

## Run from source (optional)

If you'd rather run the script directly:

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (the v2 download, not v1).
2. Double-click `AntiDoubleClick.ahk` — that's it. The tray icon (green H) appears and the small settings window opens.

## Usage

- Adjust the slider to set the debounce threshold (default 80 ms; range 5–300 ms).
- "Start with Windows" — adds a `HKCU\...\Run` registry entry so the app launches at login.
- "Start minimized to tray" — skips showing the window on launch.
- "Pause filter" — passes all clicks through unchanged. Useful for diagnosing whether the filter is causing a problem.
- Closing the window hides it to the tray; right-click the tray icon → Exit to quit.

## Verifying it works

Open https://cps-check.com/double-click-test and click rapidly with the bad mouse:
- With filter ON: only single clicks register.
- Drag the slider down to ~5 ms and click rapidly: chatter should now leak through, proving the threshold is live.
- Drag a window title bar around: drag should feel normal — confirms the Down/Up pairing is correct.

## Compiling to a single .exe

If you want a portable executable instead of running the `.ahk` script directly:

1. Right-click `AntiDoubleClick.ahk` → **Compile Script** (this menu entry is added by the AutoHotkey installer).
2. In the Ahk2Exe dialog, pick the **64-bit** base file. (Required so the hook applies to 64-bit foreground apps.)
3. Output: `AntiDoubleClick.exe` next to the script. Move that exe + `settings.json` anywhere — fully portable.

## Files

- `AntiDoubleClick.ahk` — entire app
- `settings.json` — created on first save; lives next to the script/exe
- `AntiDoubleClick.exe` — build output (only after compiling)

## How it works

The `$LButton::` / `$RButton::` / `$MButton::` hotkeys install a Windows low-level mouse hook. For each Down event the handler checks the elapsed time since the previous Down on the same button — if it's under the threshold, the event is swallowed (return without forwarding). The matching Up event is also swallowed (tracked via an `isDown` flag) so that Windows never sees an orphan release. The `$` prefix prevents the script's own `SendEvent` calls from re-triggering the hotkey.
