#Requires AutoHotkey v2.0+
#SingleInstance Force

; ===========================================================
; AltGr navigation layer for ease of use with touch typing
; Compatible with other modifiers like Shift, Ctrl and Alt
; ===========================================================

sendNav(keyBase) {
    isShift := GetKeyState("Shift", "P")
    isRCtrl := GetKeyState("RCtrl", "P")
    isLAlt  := GetKeyState("LAlt", "P")

    mods := ""
    if isShift
        mods .= "+"
    if isRCtrl
        mods .= "^"
    if isLAlt
        mods .= "!"
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
