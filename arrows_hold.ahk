#Requires AutoHotkey v2.0+
#SingleInstance Force

; ========================================================
; AltGr "arrow layer" for ease of use with touch typing
; Compatível with other modifiers like Shift or Ctrl
; ========================================================

; Ignores LCtrl becaues AltGr works by pressing LCtrl virtually
sendNav(keyBase) {
    isShift := GetKeyState("Shift", "P")
    isRCtrl := GetKeyState("RCtrl", "P")  ; <- only RCtrl

    mods := ""
    if isShift
        mods .= "+"
    if isRCtrl
        mods .= "^"

    Send(mods "{" keyBase "}")
}

RAlt & j:: sendNav("Left")
RAlt & i:: sendNav("Up")
RAlt & k:: sendNav("Down")
RAlt & l:: sendNav("Right")

RAlt & y:: sendNav("PgUp")
RAlt & h:: sendNav("PgDn")

RAlt & u:: sendNav("Home")
RAlt & o:: sendNav("End")
