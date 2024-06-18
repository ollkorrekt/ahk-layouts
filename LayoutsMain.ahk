#Requires AutoHotkey v2.0
FileEncoding "UTF-8"

#Include DeadKey.ahk
#Include Layout.ahk

;TODO add the layout changing code, which can be activated by a key press
;OPTION add ability to activate hotkey, change layout from a hotkey itself - already sort of covered by hotkey stacking, but this does not allow us to have a compound nonspacing char.
;OPTION deadkey lock, so currently active dead keys will stay on until pressed again
;TODO make a hotkey able to output a keystroke at the same time.
;OPTION add some errors to throw on invalid input files
;OPTION none of the csvs support line breaks in quotes, but they really should
;OPTION separate files into a library folder

deadKeyQueue := []
currentDefault := ''

;OPTION make these files namable from command line args
capsEffect := CapsBehavior("keyboardCapsEffects.csv")
Layout("ienne\ienneLayout.csv", 0, &currentLayout)

currentLayout := 0
layouts := 1

/* try to send a keystroke after applying the effects of all active dead keys,
 * if applicable. This function may apply multiple dead keys, feading the
 * results of applying previously pressed dead keys as inputs to later pressed
 * ones, a capability that Microsoft klc layouts do not have.
 */
deadKeySend(key)
{
    global deadKeyQueue
    global currentDefault
    if (deadKeyQueue.Length > 0) {
        deadKeySend(deadKeyLookup(deadKeyQueue.RemoveAt(1), key, currentDefault))
    } else {    
        ;first, we check the CapsLock state,
        if (getKeyState("CapsLock", "T")) {
            ;and if it's on, we need to undo the effects of capsLock on the result, because I already explicitly accounted for capsLock in the layout code.
            ;since we are using Blind, we have to do this manually, but normally, Send would do something like this for us.
            newKey := ''
            ;for each character in the sent string,
            loop parse (key){
                ;if capsLock could produce this letter, undo the capsLock.
                if (capsEffect.Has(A_LoopField)){
                    newKey .= capsEffect[A_LoopField]
                } else {
                    newKey .= A_LoopField
                }
                key := newKey
            }
        }
        
        ;TODO for some reason, Send does not work with the emoji panel. I should figure out what to do there.
        ;Send whatever we got in; it will already have been modified if a dead key was pressed.
        Send '{Blind+}{Raw}' key
       /* Sending without 'raw'could be danguerous since sent text can be edited
        * by external files. for example, {Click} and {Launch_X} are available.
        * I don't think it's too dangerous, as non-admin ahk cannot do admin
        * actions. But we use raw to be safe anyway, requiring unescaping
        * characters.
        *
        * Now I also use Blind+ to keep ignoring shift but keep all other modifiers
        */
        currentDefault := '' ;remove saved default key

        ;finally, we restore the caps state.
        ;SetCapsLockState capsState
    }
}

/* when a dead key is pressed, we put it on the stack and wait for further input
 */
deadKeyAdd(deadKeyTable){
    global deadKeyQueue
    global currentDefault
    deadKeyQueue.push(deadKeyTable)
    ;if there is a default on this key, put it in
    if (deadKeyTable.default){
        currentDefault := deadKeyTable.default
        ;TODO we should remove default if there is none?
    }
}

/* apply the effects of a dead key given in deadKeyTable (which should have
 * been read from a file spcifying the key) to the given keystroke (string).
 * Return the resulting keystroke as a string.
 */
deadKeyLookup(deadKeyTable, key, default)
{
    if (default and key == default) {
        ;if the same key is pressed again, give back the nonspacing diacritic.
        return deadKeyTable.nonspacing
    } if (deadKeyTable.Has(key)) {
        return deadKeyTable[key]
    }
   /* otherwise, we give back the nonspacing diacritic applied to the pressed
    * key as a fallback. it is an option whether to place this diacritic
    * to the right or left of the character, because placing it before can
    * be appropriate if it is not actually a combining unicode character,
    * for example if we are making a layout for hangul.
    */
    return deadKeyTable.postfix
        ? key . deadKeyTable.nonspacing
        : deadKeyTable.nonspacing . key
}

/* Switch to the next layout numerically; I still need to add a way to switch
 * to a specified layout.
 */
ChangeLayout(layoutN := "next")
{
    global currentLayout, layouts
    if (layoutN = "next") {
        layoutN := Mod(currentLayout + 1, layouts)
    }
    currentLayout := layoutN
}

CapsBehavior(filename)
{ ;OPTION make this one search various files like the other
    ;error if the capsBehavior file was not found
    if (not fileExist(filename)) {
        throw error("no file found for capsBehavior: " filename)
    }
    capsEffect := Map()
    outKey := ''

    loop read, filename {
        ;for each cell in the csv,
        loop parse, A_LoopReadLine, "CSV" {
            ;if it's the first cell, save it
            if (A_Index = 1){
                outKey := A_LoopField
            ;otherwise we put it in the map
            } else {
                capsEffect[outKey] := A_LoopField
            }
        }
    }

    return capsEffect
}
