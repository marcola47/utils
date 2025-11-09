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

; Navigation (AltGr + home row)
RAlt & j:: sendNav("Left")
RAlt & i:: sendNav("Up")
RAlt & k:: sendNav("Down")
RAlt & l:: sendNav("Right")

RAlt & y:: sendNav("PgUp")
RAlt & h:: sendNav("PgDn")

RAlt & u:: sendNav("Home")
RAlt & o:: sendNav("End")

; ===========================================================
; AltGr symbols: [, ], / with Shift selecting {, }, ?
; Ctrl/Alt modifiers are preserved; Shift is handled by the chosen char
; ===========================================================

sendSym(baseChar, shiftedChar) {
    isShift := GetKeyState("Shift", "P")
    isRCtrl := GetKeyState("RCtrl", "P")
    isLAlt  := GetKeyState("LAlt", "P")

    mods := ""
    ; Preserve Ctrl/Alt so ^/ and !/ etc. work, but don't add Shift here
    if isRCtrl
        mods .= "^"
    if isLAlt
        mods .= "!"

    char := isShift ? shiftedChar : baseChar

    ; Escape literal braces for Send()
    if (char = "{")
        char := "{{}"
    else if (char = "}")
        char := "{}}"

    Send(mods char)
}

; AltGr + , -> [ and {
RAlt & ,:: sendSym("[", "{")

; AltGr + . -> ] and }
RAlt & .:: sendSym("]", "}")

; AltGr + m -> / and ?
RAlt & m:: sendSym("/", "?")
