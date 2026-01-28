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
; Ctrl/Alt modifiers are preserved; Shift é decidido pelo caractere
; ===========================================================

sendSym(baseChar, shiftedChar) {
    isShift := GetKeyState("Shift", "P")
    isRCtrl := GetKeyState("RCtrl", "P")
    isLAlt  := GetKeyState("LAlt", "P")

    mods := ""
    if isRCtrl
        mods .= "^"
    if isLAlt
        mods .= "!"

    char := isShift ? shiftedChar : baseChar

    if (char = "{")
        char := "{{}"
    else if (char = "}")
        char := "{}}"
    else if (char = "+")
        char := "{+}"
    else if (char = "^")
        char := "{^}"
    else if (char = "!")
        char := "{!}"
    else if (char = "#")
        char := "{#}"

    Send(mods char)
}

; AltGr + , -> [ e { (com Shift)
RAlt & ,:: sendSym("[", "{")

; AltGr + . -> ] e } (com Shift)
RAlt & .:: sendSym("]", "}")

; AltGr + m -> / e ?
RAlt & m:: sendSym("/", "?")

; AltGr + b -> - and _
RAlt & b:: sendSym("-", "_")

; AltGr + n -> = and +
RAlt & n:: sendSym("=", "+")

; I could add another symbol in the shift modifier
; AltGr + d/f -> (/)
RAlt & d:: sendSym("(", "(")
RAlt & f:: sendSym(")", ")")
