#Requires AutoHotkey v2.0
FileEncoding "UTF-8"

;TODO add the layout changing code, which can be activated by a key press
;OPTION add ability to activate hotkey, change layout from a hotkey itself - already sort of covered by hotkey stacking, but this does not allow us to have a compound nonspacing char.
;OPTION deadkey lock, so currently active dead keys will stay on until pressed again
;TODO make a hotkey able to output a keystroke at the same time.
;TODO replace escapes and {} chars when passed in, for security and to allow, for example, {U+e000} = {u+E000}
;TODO add support for a layout file remembering its folder
;OPTION add some errors to throw on invalid input files
;OPTION allow comments columns in csvs

deadKeyQueue := []
currentDefault := ''

readLayout("ienne\ienneLayout.csv", 0)
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
    global currentDefault
    if (deadKeyQueue.Length > 0) {
        deadKeySend(deadKeyLookup(deadKeyQueue.RemoveAt(1), key, currentDefault))
    } else {
        Send key ;maybe should use raw mode here, but want character escapes.
        /* could be danguerous since sent text can be edited by external files.
         * for example, {Click} and {Launch_X} are available. To be safe, we
         * should reccomend to make layout files administrator read only, maybe.
         * I don't think it's too dangerous, as non-admin ahk cannot do admin
         * actions.
         */
        currentDefault := ''
    }
}

/* when a dead key is pressed, we put it on the stack and wait for further input
 */
deadKeyAdd(deadKeyTable){
    global deadKeyQueue
    global currentDefault
    deadKeyQueue.push(deadKeyTable)
    if (deadKeyTable.HasOwnProp("default")){
        currentDefault := deadKeyTable.default
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
    ;error if the layout file was not found
    if (not fileExist(file)) {
        throw error("no file found for layout: " file)
    }
    HotIf((*) => layout == layoutN) ;only enabled if the layout is selected
    
    local layoutDir
    SplitPath(file,, &layoutDir) ;get the directory of this file for use later
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
            deadKeyTable := readDeadKey(deadKeyFile, currentKey, layoutDir)
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

readDeadKey(file, pressedKey, layoutDir)
{
    static deadKeyDirName := "deadKeys"
    ;initialize vars:
    ;create a number of possible file locations
    layoutDirFile := layoutDir '\' file
    layoutSubdirFile := layoutDir '\' deadKeyDirName '\' file
    subdirFile := deadKeyDirName '\' file
    ;use the first file location where the file was found
    foundFile := FileExist(layoutSubdirFile)
        ? layoutSubdirFile
        : FileExist(layoutDirFile)
            ? layoutDirFile
            : FileExist(subdirFile)
                ? subdirFile
                : FileExist(file)
                    ? file
                    : ''
    ;error if the dead key file was not found at all
    if (not foundFile) {
        throw error("no file found for dead key: " file)
    }
    ;the return table to contain a specification of the dead key
    keyTable := Map()
    keyTable.nonspacing := ''
    keyTable.postfix := True
    /* keyTable.nonspacing is what to send when no specified key combination is
     * pressed;
     * keyTable.default is the key to press to directly get nonspacing; if it is
     * not defined, you cannot do that;
     * keyTable.postfix to place "nonspacing" ver. of diacritic to the right or
     * left of a given key combination. True for postfix, False for prefix.
     * 
     * maybe it's obvious that this should be a class, but then again perhaps so
     * should some other values I'm not sure of.
     */
    local currentKey ;stored keystroke value to be used when result is read

    loop read, foundFile {
        lineN := A_Index
        ;for each cell in the csv,
        loop parse, A_LoopReadLine, "CSV" {
            cellN := A_Index
            cellText := A_LoopField
            ;the cells in the header
            if (lineN = 1) {
                ;first cell optionally specifies an alternate default keystroke
                if (cellN = 1){
                    /* if this cell is false but not blank, no default will be
                     * used; usu. for dead keys that do not have a non-spacing
                     * variant and which need the slot of their key for a
                     * combination, like the ienne layout's 6 -> ⁶
                     */
                    if (cellText and (cellText != "False")){
                        keyTable.default := cellText
                    ;otherwise if it's blank use a default same as the dead key
                    } else if (cellText = ""){
                        keyTable.default := pressedKey
                    }
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
