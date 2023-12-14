#Requires AutoHotkey v2.0

normalizeEscapes(rawString)
{
    normalizedString := normalizeBraces(normalizeTicks(rawString))
    return normalizedString
}

;TODO document
;I choose to give invalid brace escapes literally to make files easier to write,
;unlike ahk's send behavior.
normalizeBraces(rawString){
   /* We only want the escaped characters, not any escaped clicks or anything;
    * those could be too dangerous. Furthermore, we want any escaped characters
    * to be treated the same as equivalent sequences, or as the literals.
    */
    ;OPTION perhaps I shouldn't find as an opening brace `{, but ahk does.
    local foundBrace
    local foundClosingBrace
    local normalizedString := ""
    While (foundBrace := InStr(rawString, '{')){
        foundClosingBrace := InStr(rawString, '}', "Off", foundBrace)
        if (not foundClosingBrace){
            break ; as if there were no more found braces
        }
        normalizedString .= SubStr(rawString, 1, foundBrace - 1)
        sequenceLength := foundClosingBrace - foundBrace - 1
        escapeSequence := SubStr(rawString, foundbrace+1, sequenceLength)
        rawString := SubStr(rawString, foundClosingBrace+1)
        convertedEscape := ""
        ;OPTION allow sending some of these with a specific exception
       /* Don't currently cover the following brace escape sequences, which may
        * be safe:
        * {Escape}, {Esc}, {Ctrl} etc., {Alt} etc., {LWin} etc., {AppsKey},
        *     {Sleep}, {vkXXscYYY} etc., {Browser_Back} etc., {Volume_Mute}
        *     etc., {Launch_X}, {CtrlBreak}, {Pause}, {Click} etc., {LButton}
        *     etc., all because of security concerns - note that sending escape
        *     might still be possible with control chars.
        * {Delete}, {Del}, {Insert}, {Ins}, {Up}, {Down}, {Left}, {Right},
        *     {Home}, {End}, {PgUp}, {PgDn}, {CapsLock}, {ScrollLock},
        *     {NumLock}, {Shift}, {LShift}, {RShift}, {Shift down}, {Numpad0}
        *     etc., {PrintScreen} as there is no clear way to send these in raw
        *     mode.
        * {Blind}
        */
        switch escapeSequence, "Off" {
        case 'Text', 'Raw':
        ;OPTION make text mode work differently from raw
       /* raw mode will be active anyway, so just ignore this tag and then exit
        * out of text processing, ignoring other brace escapes.
        */
            break
        case "":
        ;look for the special escape sequence '{}}'
            if (Substr(rawString, 1, 1) = '}'){
                rawString := SubStr(rawString, 2)
                convertedEscape := '}'
            } else {
                convertedEscape := '{}'
            }
        case '!', '#', '+', '^', '{':
        ;escape sequences that just output that character
            convertedEscape := escapeSequence
        case 'Enter':
            convertedEscape := '`n'
        case 'Space':
            convertedEscape := ' '
        case 'Tab':
            convertedEscape := '`t'
        case 'Backspace', 'BS':
            convertedEscape := '`b'
        default:
            ;Alt Codes
            if (SubStr(escapeSequence, 1, 4) = "ASC ") {
                try {
                    convertedEscape := lookupAltCode(SubStr(escapeSequence, 5))
                } catch ValueError {
                    convertedEscape := '{' escapeSequence '}'
                }
            ;unicode
            } else if (SubStr(escapeSequence, 1, 2) = "U+") {
                try {
                    codePoint := '0x' . SubStr(escapeSequence, 3)
                    convertedEscape := chr(codePoint)
                } catch ValueError, TypeError {
                    convertedEscape := '{' escapeSequence '}'
                }
            ;not a valid brace escape
            } else {
                convertedEscape := '{' escapeSequence '}'
            }
        }
        normalizedString .= convertedEscape
    }
    return normalizedString . rawString
}

;TODO document this
normalizeTicks(rawString){
    local foundTick
    local normalizedString := ""
    While (foundTick := InStr(rawString, '``')){
        normalizedString .= SubStr(rawString, 1, foundTick - 1)
        ;backtick at the end of a string cannot occur in ahk files
        if (foundTick = StrLen(rawString)){
            ;let's just put a literal backtick in this case.
            normalizedString .= '``'
        }
        escapeCharacter := SubStr(rawString, foundTick+1, 1)
        rawString := SubStr(rawString, foundTick+2)
        switch escapeCharacter, "Off" {
        case 'n': ;newline
            convertedEscape := '`n'
        case 'r': ;carriage return
            convertedEscape := '`r'
        case 'b': ;backspace
            convertedEscape := '`b'
        case 't': ;tab
            convertedEscape := '`t'
        case 's': ;space
            convertedEscape := '`s'
        case 'v': ;vertical tab
            convertedEscape := '`v'
        case 'a': ;bell
            convertedEscape := '`a'
        case 'f': ;formfeed
            convertedEscape := '`f'
        default:
           /* for all other sequences, including the documented sequences ``,
            * `;, `{, `", or `', ahk produces the literal character.
            */
            convertedEscape := escapeCharacter
        }
        normalizedString .= convertedEscape
    }
    return normalizedString . rawString
}
