#Requires AutoHotkey v2.0

#Include NormalizeEscapes.ahk

class DeadKey{
    ;the table to contain a specification of the dead key
    keyTable := Map()
    nonspacing := ''
    postfix := True
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

    ;TODO document this
    __New(filename, pressedKey, layoutDir)
    {
        static deadKeyDirName := "deadKeys"
        ;initialize vars:
        ;create a number of possible file locations
        layoutDirFile := layoutDir '\' filename
        layoutSubdirFile := layoutDir '\' deadKeyDirName '\' filename
        subdirFile := deadKeyDirName '\' filename
        ;use the first file location where the file was found
        foundFile := FileExist(layoutSubdirFile)
            ? layoutSubdirFile
            : FileExist(layoutDirFile)
                ? layoutDirFile
                : FileExist(subdirFile)
                    ? subdirFile
                    : FileExist(filename)
                        ? filename
                        : ''
        ;error if the dead key file was not found at all
        if (not foundFile) {
            throw error("no file found for dead key: " filename)
        }

        local currentKey ;stored keystroke value to be used when result is read

        loop read, foundFile {
            lineN := A_Index
            ;for each cell in the csv,
            loop parse, A_LoopReadLine, "CSV" {
                cellN := A_Index
                ;normalize any escape sequences to their literal chars
                cellText := normalizeEscapes(A_LoopField)
                ;the cells in the header
                if (lineN = 1) {
                    ;first cell optionally specifies an alternate default keystroke
                    switch cellN
                    {
                    case 1:
                    /* if this cell is false but not blank, no default will be
                        * used; usu. for dead keys that do not have a non-spacing
                        * variant and which need the slot of their key for a
                        * combination, like the ienne layout's 6 -> ⁶
                        */
                        if (cellText and (cellText != "False")){
                            this.default := cellText
                        ;otherwise if it's blank use a default same as the dead key
                        } else if (cellText = ""){
                            this.default := pressedKey
                        }
                    case 2:
                        firstChar := SubStr(cellText, 1, 1)
                        if (firstChar = '<' or firstChar = '>') {
                            cellText := SubStr(cellText, 2)
                            this.postfix := firstChar = '>'
                        }
                        this.nonspacing := cellText
                   /* There is no default case; other cells that are not in the
                    * first two columns are ignored as comments
                    */
                    }
                ;interpret a key header
                } else switch (cellN) {
                case 1:
                    currentKey := cellText
                ;interpret a key's result when the dead key is applied to it
                case 2:
                    this.keyTable[currentKey] := cellText
                ;again, any other cells will be ignored as comments.
                }
            }
        }
    }

    __Item[key]
    {
        get => this.keyTable[key]
        set => this.keyTable[key] := value
    }

    Has(key) => this.keyTable.Has(key)
}
