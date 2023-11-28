#Requires AutoHotkey v2.0
FileEncoding "UTF-8"

;TODO add the layout changing code, which can be activated by a key press
;OPTION add ability to activate hotkey, change layout from a hotkey itself
;OPTION deadkey lock, so currently active dead keys will stay on until pressed again
;TODO make a hotkey able to output a keystroke at the same time.
;TODO replace escapes and {} chars when passed in, for security and to allow, for example, {U+e000} = {u+E000}
;TODO add support for a layout file remembering its folder
;OPTION add some errors to throw on invalid input files
;OPTION allow comments columns in csvs
/*heartKeyTable := Map(
    "H", "♥"
)
heartKeyTable.nonspacing := "H"
heartKeyTable.default := "7"
heartKeyTable.postfix := True ; to place "nonspacing" ver. of diacritic to the right or left
deadKeyQueue := [heartKeyTable]*/
deadKeyQueue := []

readLayout("ienneLayout.csv", 0)
layout := 0
layouts := 1

/* try to send a keystroke after applying the effects of all active dead keys,
 * if applicable. This function may apply multiple dead keys, feading the
 * results of applying previously pressed dead keys as inputs to later pressed
 * ones, a capability that Microsoft klc layouts do not have.
 */
deadKeySend(key)
{
    global deadKeyQueue
    if (deadKeyQueue.Length > 0) {
        deadKeySend(deadKeyLookup(deadKeyQueue.RemoveAt(1), key))
    } else {
        Send key ;maybe should use raw mode here, but want character escapes.
        /* could be danguerous since sent text can be edited by external files.
         * for example, {Click} and {Launch_X} are available. To be safe, we
         * should reccomend to make layout files administrator read only, maybe.
         * I don't think it's too dangerous, as non-admin ahk cannot do admin
         * actions.
         */
    }
}

/* when a dead key is pressed, we put it on the stack and wait for further input
 */
deadKeyAdd(deadKeyTable){
    global deadKeyQueue
    deadKeyQueue.push(deadKeyTable)
}

/* apply the effects of a dead key given in deadKeyTable (which should have
 * been read from a file spcifying the key) to the given keystroke (string).
 * Return the resulting keystroke as a string.
 */
deadKeyLookup(deadKeyTable, key)
{
    if (deadKeyTable.Has(key)) {
        return deadKeyTable[key]
    } if (deadKeyTable.HasOwnProp("default") and key == deadKeyTable.default) {
        ;if the same key is pressed again, give back the nonspacing diacritic.
        return deadKeyTable.nonspacing
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
    global layout, layouts, enable, disable
    if (layoutN = "next") {
        layoutN := Mod(layout + 1, layouts)
    }
}  

/* Take in a keyboard layout from the specified file and enable all its
 * hotkeys (when layoutN is the one selected). I perhaps want some way to enable
 * more layouts at once than just one... maybe making layout a complex object
 * would work.
 */
readLayout(file, layoutN)
{
    HotIf((*) => layout == layoutN) ;only enabled if the layout is selected
    
    ;initialize vars:
    modifiers := []
    local currentKey ;always gets set within processCsvField
    capsColumns := Map() ;which cols are used to mark caps=shift for a row
    modifierColumns := Map() ;tell the index of each modifier
    capsAreShifts := Map("", True, "+", True)
    local keyFs ;function to run for each hotkey; reset before each row.

    loop read, file {
        lineN := A_Index
        keyFs := []
        ;for each cell in the csv,
        loop parse, A_LoopReadLine, "CSV" {
            ;process the field and put its function here if applicable
            keyFs.Push(processCsvField(lineN, A_Index, A_LoopField)) 
        }
        ; then, for each of the resulting functions,
        loop keyFs.Length {
            ;(if the function actually exists)
            if (not keyFs[A_Index]) {
                continue
            }
            modifiedKey := modifiers[A_Index] . currentKey
            ;edit the function if neccesary
            processedF := processF(A_Index)
            ;then turn on its hotkey.
            Hotkey modifiedKey, processedF, "On"
            ;maybe I should put in a way to disable layout altogether? not now
        }
    }
    
    /* Read in a csv field and either interpret it as a header if it is in the
     * first row or column or interpret it as specifying a layout entry or a
     * caps lock behavior tag otherwise; this was split into another function to
     * allow returning the function as a closure, but it accesses many of the
     * outer function's vars.
     */
    processCsvField(lineN, cellN, cellText)
    {
        static capsString := "capsIsShift" ;whatever, don't like magic num
        static deadKeyString := "DeadKey:"
        ;interpret a column header
        if (lineN == 1) {
            ;is this a caps behavior column?
            local taglessModifer := StrReplace(cellText, capsString, "")
            capsColumns[cellN] := cellText != taglessModifer
            ;normalize to make modifier easy to work with.
            taglessModifer := normalizeModifier(taglessModifer)
            ;put it on the lists
            modifiers.Push(taglessModifer)
            modifierColumns[taglessModifer] := cellN
        ;interpret a key header
        } else if (cellN = 1){
            currentKey := cellText
        ;interpret a caps lock column cell
        } else if (capsColumns[cellN]){
            ;caps will =shift if the cell evaluates to false or is that text
            local capsIsShift := cellText and (cellText != "false")
            local modifier := modifiers[cellN]
            local toggledModifier := toggleShift(modifier)
            capsAreShifts[modifier] := capsIsShift
            capsAreShifts[toggledModifier] := capsIsShift
        ;interpret a deadkey (which should specify another csv file)
        } else if (Substr(cellText, 1, StrLen(deadKeyString)) = deadKeyString) {
            deadKeyFile := Substr(cellText, StrLen(deadKeyString) + 1)
            deadKeyTable := readDeadKey(deadKeyFile, currentKey)
            return (*) => deadKeyAdd(deadKeyTable)
        ;interpret a normal cell
        } else {
            return (*) => deadKeySend(cellText)
        }
    }

    /* Modify our function to apply capsLock; this had to be done separately
     * because the column specifying caps lock behavior could come after the 
     * cols specifying whichever particular modifier with and without shift held
     * down. Split to return a closure.
     */
    processF(columnN)
    {
        local modifier := modifiers[columnN]
        local f := keyFs[columnN]
        ;Normally, caps lock does nothing.
        if (not capsAreShifts.Has(modifier) or not capsAreShifts[modifier]) {
            return f
        }
        ;but if caps=shift for this modifier, caps lock will switch shift state.
        local toggledModifier := toggleShift(modifier)
        local toggledF := keyFs[modifierColumns[toggledModifier]]
        return applyCapsF
        
        /* Effectively switch shift state if caps lock is on (by using the
         * function for the shift-toggled version of this hotkey).
         */
        applyCapsF(*)
        {
            if (getKeyState("CapsLock", "T")) {
                toggledF()
            } else {
                f()
            }
        }
    }
}

readDeadKey(file, pressedKey)
{
    ;initialize vars:
    ;the return table to contain a specification of the dead key
    keyTable := Map()
    keyTable.nonspacing := ''
    keyTable.default := pressedKey
    keyTable.postfix := True
    /* keyTable.nonspacing is what to send when no specified key combination is
     * pressed;
     * keyTable.default is the key to press to directly get nonspacing;
     * keyTable.postfix to place "nonspacing" ver. of diacritic to the right or
     * left of a given key combination. True for postfix, False for prefix.
     * 
     * maybe it's obvious that this should be a class, but then again perhaps so
     * should some other values I'm not sure of.
     */
    local currentKey ;stored keystroke value to be used when result is read

    loop read, file {
        lineN := A_Index
        ;for each cell in the csv,
        loop parse, A_LoopReadLine, "CSV" {
            cellN := A_Index
            cellText := A_LoopField
            ;the cells in the header
            if (lineN = 1) {
                ;first cell optionally specifies an alternate default keystroke
                if (cellN = 1 and cellText){
                    keyTable.default := cellText
                    ;TODO if this cell is false, no default will be used.
                } else if (cellN = 2) {
                    firstChar := SubStr(cellText, 1, 1)
                    if (firstChar = '<' or firstChar = '>') {
                        cellText := SubStr(cellText, 2)
                        keyTable.postfix := firstChar = '>'
                    }
                    keyTable.nonspacing := cellText
                }
            ;interpret a key header
            } else if (cellN = 1){
                currentKey := cellText
            ;interpret a key's result when the dead key is applied to it
            } else if (cellN = 2) {
                keyTable[currentKey] := cellText
            }
        }
    }
    return keyTable
}

/* Given a normalized hotkey modifier, toggle whether shift is held (i.e.,
 * whether "+" is present).
 */
toggleShift(modifier)
{
    maybePlus := SubStr(modifier, -1)
    if (maybePlus = "+") {
        return SubStr(modifier, 1, -1)
    }
    return modifier . "+"
}

/* Normalize a hotkey modifier, possibly rearranging the symbols in it so that
 * I don't have to worry about the fact that their order is not set later.
 * Currently, it just always puts + at the end of the list of modifiers, so that
 * I can toggle shift easily.
 */
normalizeModifier(modifier)
{
    plusless := StrReplace(modifier, "+", "")
    if (plusless != modifier) {
        return plusless . "+"
    }
    return plusless
}
