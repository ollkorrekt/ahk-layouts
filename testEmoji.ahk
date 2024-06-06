; #Requires AutoHotkey v2.0
; DetectHiddenWindows true

; ; !1::
; ; {
; ;     global title
; ;     title := WinGetText(, 'Input Exp')
; ; }
; ; !2::MsgBox(title)

; SetTimer WatchCursor, 100

; WatchCursor()
; {
;     MouseGetPos , , &id, &control
;     ToolTip
;     (
;         "ahk_id " id "
;         ahk_class " WinGetClass(id) "
;         " WinGetTitle(id) "
;         Control: " control
;     )
; }

!^1::Send('hello')