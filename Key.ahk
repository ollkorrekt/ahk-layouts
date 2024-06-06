#Requires AutoHotkey v2.0
;'imports' deadKeyAdd, deadKeySend from LayoutsMain, DeadKey from DeadKey

class Key {
    ;TODO add docs, delegate more responsibilities to this class
    action := (*) => ''
    deadKeyTable := ''
    keyType := ''

    __New(cellText, modifier, capsIsShift, currentKey, layoutDir){
        static deadKeyString := "DeadKey:"

        ;interpret a deadkey (which should specify another csv filename)
        if (Substr(cellText, 1, StrLen(deadKeyString)) = deadKeyString) {
            deadKeyFile := Substr(cellText, StrLen(deadKeyString) + 1)
            deadKeyTable := DeadKey(deadKeyFile, currentKey, layoutDir)
            this.action := (*) => deadKeyAdd(deadKeyTable)
        ;interpret a normal cell
        } else {
            this.action := (*) => deadKeySend(cellText)
        }
    } 
}