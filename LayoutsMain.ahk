#Requires AutoHotkey v2.0
FileEncoding "UTF-8"

#Include DeadKey.ahk
#Include Layout.ahk

;TODO add the layout changing code, which can be activated by a key press
;OPTION add ability to activate hotkey, change layout from a hotkey itself - already sort of covered by hotkey stacking, but this does not allow us to have a compound nonspacing char.
;OPTION deadkey lock, so currently active dead keys will stay on until pressed again
;TODO make a hotkey able to output a keystroke at the same time.
;OPTION add some errors to throw on invalid input files
;OPTION allow comments columns in csvs
;OPTION none of the csvs support line breaks in quotes, but they really should

deadKeyQueue := []
currentDefault := ''

Layout("ienne\ienneLayout.csv", 0)
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
        Send '{Raw}' key
       /* Sending without 'raw'could be danguerous since sent text can be edited
        * by external files. for example, {Click} and {Launch_X} are available.
        * I don't think it's too dangerous, as non-admin ahk cannot do admin
        * actions. But we use raw to be safe anyway, requiring unescaping
        * characters.
        */
        currentDefault := '' ;remove saved default key
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
    global currentLayout, layouts, enable, disable
    if (layoutN = "next") {
        layoutN := Mod(currentLayout + 1, layouts)
    }
}  
