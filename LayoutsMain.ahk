#Requires AutoHotkey v2.0
FileEncoding "UTF-8"

#Include DeadKey.ahk
#Include NormalizeEscapes.ahk

;TODO add the layout changing code, which can be activated by a key press
;OPTION add ability to activate hotkey, change layout from a hotkey itself - already sort of covered by hotkey stacking, but this does not allow us to have a compound nonspacing char.
;OPTION deadkey lock, so currently active dead keys will stay on until pressed again
;TODO make a hotkey able to output a keystroke at the same time.
;OPTION add some errors to throw on invalid input files
;OPTION allow comments columns in csvs
;OPTION none of the csvs support line breaks in quotes, but they really should

deadKeyQueue := []
currentDefault := ''

readLayout("ienne\ienneLayout.csv", 0)
layout := 0
layouts := 1

#Include "lookupAltCode.ahk"

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
    } if (deadKeyTable.keyTable.Has(key)) {
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
readLayout(filename, layoutN)
{
    ;error if the layout file was not found
    if (not fileExist(filename)) {
        throw error("no file found for layout: " filename)
    }
    ;TODO hotIf any condition
    HotIf((*) => layout == layoutN) ;only enabled if the layout is selected
    
    local layoutDir
    SplitPath(filename,, &layoutDir) ;get the directory of this file for use later
    ;initialize vars:
    modifiers := []
    local currentKey ;always gets set within processCsvField
    capsColumns := Map() ;which cols are used to mark caps=shift for a row
    modifierColumns := Map() ;tell the index of each modifier
    capsAreShifts := Map("", True, "+", True)
    local keyFs ;function to run for each hotkey; reset before each row.
   /* flag that flips once we find a column with an empty header; only the first
    * column will be treated as having an empty modifier, and others will be
    * comment columns.
    */
    local unmodifiedColFound := False

    loop read, filename {
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
        static modifierString := "Modifier"
        static capsString := "capsIsShift" ;whatever, don't like magic num
        static deadKeyString := "DeadKey:"
        static commentString := "Comment"
        ;get rid of escape sequences.
        cellText := normalizeEscapes(cellText)
        switch {
        ;interpret a column header
        case (lineN = 1):
            ;if this is the first column, we just ignore its header
            if (cellN = 1){
                modifiers.push(modifierString)
                modifierColumns[modifierString] := 1
                capsColumns[1] := False
                return
            }
            ;make this column a comment col if it's not the first empty column.
            if (cellText = ""){
                if (not unmodifiedColFound){
                    unmodifiedColFound := True
                } else {
                    cellText := commentString
                }
            }
            ;is this a caps behavior column?
            local taglessModifier := StrReplace(cellText, capsString, "")
            local isCapsColumn := cellText != taglessModifier
            capsColumns[cellN] := isCapsColumn
            ;normalize to make modifier easy to work with.
            taglessModifier := normalizeModifier(taglessModifier)
            ;put it on the lists
            modifiers.Push(taglessModifier)
           /* We want to skip it if this is just a tag column so it doesn't
            * overwrite the location of the real column.
            */
            if (not isCapsColumn){
                modifierColumns[taglessModifier] := cellN
            }
        ;interpret a key header
        case (cellN = 1):
            currentKey := cellText
        ;interpret a caps lock column cell
        case (capsColumns[cellN]):
            ;caps will =shift if the cell evaluates to false or is that text
            capsIsShift := cellText and (cellText != "false")
            modifier := modifiers[cellN]
            toggledModifier := toggleShift(modifier)
            capsAreShifts[modifier] := capsIsShift
            capsAreShifts[toggledModifier] := capsIsShift
       /* interpret a comment cell, that is, one which is marked "comment" in
        * the header, or one which has an empty header other than the first.
        */
        case modifiers[cellN] = commentString:
            return ;just do nothing.
        ;interpret a deadkey (which should specify another csv filename)
        case (Substr(cellText, 1, StrLen(deadKeyString)) = deadKeyString):
            deadKeyFile := Substr(cellText, StrLen(deadKeyString) + 1)
            deadKeyTable := DeadKey(deadKeyFile, currentKey, layoutDir)
            return (*) => deadKeyAdd(deadKeyTable)
        ;interpret a normal cell
        default:
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

;TODO document this, add support for backtick escapes too.


