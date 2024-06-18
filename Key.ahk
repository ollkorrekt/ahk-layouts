#Requires AutoHotkey v2.0
;'imports' deadKeyAdd, deadKeySend from LayoutsMain
#Include DeadKey.ahk
;TODO remove circular reliances

class Key {
    ;TODO add docs, delegate more responsibilities to this class

    __New(cellText, modifier, capsIsShift, currentKey, layoutDir){
        static deadKeyString := "DeadKey:"

        ;interpret a deadkey (which should specify another csv filename)
        if (Substr(cellText, 1, StrLen(deadKeyString)) = deadKeyString) {
            this.keyType := "dead"
            deadKeyFile := Substr(cellText, StrLen(deadKeyString) + 1)
            this.data := DeadKey(deadKeyFile, currentKey, layoutDir)
        ;interpret a normal cell
        } else {
            this.keyType := "normal"
            this.data := cellText
        }
    }

    action(name:=''){
        switch (this.keyType){
        case "normal": deadKeySend(this.data)
        case "dead": deadKeyAdd(this.data)
        }
    }
}