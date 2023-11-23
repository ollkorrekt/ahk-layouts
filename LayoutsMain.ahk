FileEncoding "UTF-8"

heartKeyTable := Map(
    "H", "♥"
)
heartKeyTable.nonspacing := "H"
heartKeyTable.default := "7"
heartKeyTable.postfix := True ; to place "nonspacing" ver. of diacritic to the right or left
deadKeyStack := [heartKeyTable]

readLayout("normalKeys.csv", 0)
layout := 0
layouts := 1

/* try to send a keystroke after applying the effects of all active dead keys,
 * if applicable. This function may apply multiple dead keys, feading the
 * results of applying previously pressed dead keys as inputs to later pressed
 * ones, a capability that Microsoft klc layouts do not have.
 */
deadKeySend(key)
{
    global deadKeyStack
    if (deadKeyStack.Length > 0) {
        deadKeySend(deadKeyLookup(deadKeyStack.Pop(), key))
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

dead

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
        local static capsString := "capsIsShift" ;whatever, don't like magic num
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
        ;interpret a normal cell
        } else {
            return (*) => deadKeySend(cellText)
            ;TODO add dead key code here
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

readDeadKey(file)
{

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
