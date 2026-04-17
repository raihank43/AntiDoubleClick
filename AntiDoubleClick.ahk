#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== Settings =====
SettingsPath := A_ScriptDir "\settings.json"
RUN_KEY := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
APP_NAME := "AntiDoubleClick"

LoadSettings() {
    s := Map("threshold", 80, "startMinimized", false, "autostart", false)
    if !FileExist(SettingsPath)
        return s
    try {
        text := FileRead(SettingsPath, "UTF-8")
        if RegExMatch(text, '"threshold"\s*:\s*(\d+)', &m)
            s["threshold"] := Integer(m[1])
        if RegExMatch(text, '"startMinimized"\s*:\s*(true|false)', &m)
            s["startMinimized"] := (m[1] = "true")
        if RegExMatch(text, '"autostart"\s*:\s*(true|false)', &m)
            s["autostart"] := (m[1] = "true")
    }
    return s
}

SaveSettings() {
    json := Format('{`n  "threshold": {1},`n  "startMinimized": {2},`n  "autostart": {3}`n}',
        settings["threshold"],
        settings["startMinimized"] ? "true" : "false",
        settings["autostart"] ? "true" : "false")
    try FileDelete(SettingsPath)
    FileAppend(json, SettingsPath, "UTF-8")
}

settings := LoadSettings()

; ===== Filter state =====
lastDown := Map("LButton", 0, "RButton", 0, "MButton", 0)
isDown   := Map("LButton", false, "RButton", false, "MButton", false)
filterPaused := false

HandleDown(btn, *) {
    now := A_TickCount
    if (now - lastDown[btn] < settings["threshold"])
        return  ; chatter — swallow
    lastDown[btn] := now
    isDown[btn] := true
    SendEvent "{Blind}{" btn " Down}"
}

HandleUp(btn, *) {
    if !isDown[btn]
        return  ; we swallowed the matching Down — swallow this Up too
    isDown[btn] := false
    SendEvent "{Blind}{" btn " Up}"
}

; Register hotkeys with $ prefix so our own SendEvent calls don't recurse.
HOTKEYS := [
    ["$LButton",    HandleDown.Bind("LButton")],
    ["$LButton Up", HandleUp.Bind("LButton")],
    ["$RButton",    HandleDown.Bind("RButton")],
    ["$RButton Up", HandleUp.Bind("RButton")],
    ["$MButton",    HandleDown.Bind("MButton")],
    ["$MButton Up", HandleUp.Bind("MButton")],
]
for hk in HOTKEYS
    Hotkey(hk[1], hk[2])

SetFilterPaused(paused) {
    global filterPaused
    filterPaused := paused
    state := paused ? "Off" : "On"
    for hk in HOTKEYS
        Hotkey(hk[1], state)
    if paused {
        A_TrayMenu.Check("Pause filter")
        A_IconTip := APP_NAME " — paused"
        if IsSet(statusCtrl)
            statusCtrl.Text := "Status: PAUSED"
    } else {
        A_TrayMenu.Uncheck("Pause filter")
        A_IconTip := APP_NAME " — filter on"
        if IsSet(statusCtrl)
            statusCtrl.Text := "Status: filter ON"
    }
}

TogglePause(*) {
    SetFilterPaused(!filterPaused)
}

; ===== Autostart =====
SetAutostart(enabled) {
    settings["autostart"] := !!enabled
    SaveSettings()
    target := A_IsCompiled
        ? '"' A_ScriptFullPath '"'
        : '"' A_AhkPath '" "' A_ScriptFullPath '"'
    if enabled
        RegWrite(target, "REG_SZ", RUN_KEY, APP_NAME)
    else
        try RegDelete(RUN_KEY, APP_NAME)
}

; ===== GUI =====
mainGui := Gui("+AlwaysOnTop +ToolWindow", APP_NAME)
mainGui.SetFont("s10", "Segoe UI")
mainGui.OnEvent("Close", (*) => mainGui.Hide())
mainGui.OnEvent("Escape", (*) => mainGui.Hide())

mainGui.Add("Text", "xm", "Debounce threshold")
sliderCtrl := mainGui.Add("Slider", "xm w260 Range5-300 ToolTip", settings["threshold"])
labelCtrl  := mainGui.Add("Text",   "xm w260 Center", settings["threshold"] " ms")

sliderCtrl.OnEvent("Change", (*) => (
    settings["threshold"] := sliderCtrl.Value,
    labelCtrl.Text := sliderCtrl.Value " ms",
    SaveSettings()
))

autostartCb := mainGui.Add("Checkbox", "xm y+12", "Start with Windows")
autostartCb.Value := settings["autostart"]
autostartCb.OnEvent("Click", (*) => SetAutostart(autostartCb.Value))

minimizedCb := mainGui.Add("Checkbox", "xm", "Start minimized to tray")
minimizedCb.Value := settings["startMinimized"]
minimizedCb.OnEvent("Click", (*) => (
    settings["startMinimized"] := minimizedCb.Value,
    SaveSettings()
))

pauseCb := mainGui.Add("Checkbox", "xm", "Pause filter")
pauseCb.OnEvent("Click", (*) => SetFilterPaused(pauseCb.Value))

statusCtrl := mainGui.Add("Text", "xm y+10 w260", "Status: filter ON")
mainGui.Add("Text", "xm w260", "Tip: close window to hide to tray.")

; If autostart was enabled but the run-key was wiped manually, re-register.
if settings["autostart"] {
    try existing := RegRead(RUN_KEY, APP_NAME)
    if !IsSet(existing) || existing = ""
        SetAutostart(true)
}

; ===== Tray =====
A_TrayMenu.Delete()
A_TrayMenu.Add("Show", (*) => mainGui.Show())
A_TrayMenu.Add("Pause filter", TogglePause)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show"
A_IconTip := APP_NAME " — filter on"

if !settings["startMinimized"]
    mainGui.Show()
