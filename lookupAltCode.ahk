/* Takes in a string representing a number typed on the keypad and returns its
 * character when interpreted as an alt code. Currently, does not accept hex
 * input with the prefixed +.
 */
lookupAltCode(numberString){
    ;characters less than 256 are not treated as unicode
    if (numberString < 256){
        ;TODO hex input should be treated without the 0x right?
        ;if there is a prefixed zero, use ANSI characters
        if (SubStr(numberString, 1, 1) = '0'){
            ;Windows-1252 codes which override the Latin-1 control chars
            switch (numberString){
                case 128: return '€'
                ;control character HOP
                case 130: return '‚' ;low left single curly quote
                case 131: return 'ƒ'
                case 132: return '„' ;low left double curly quote
                case 133: return '…'
                case 134: return '†'
                case 135: return '‡'
                case 136: return 'ˆ' ;spacing circumflex diacritic, not ^
                case 137: return '‰'
                case 138: return 'Š'
                case 139: return '‹' ;left single guillemet
                case 140: return 'Œ'
                ;control character RI
                case 142: return 'Ž'
                ;control character SS3
                ;control character DCS
                case 145: return "‘" ;left single curly quote
                case 146: return "’" ;right single curly quote/curly apostrophe
                case 147: return '“' ;left double curly quote
                case 148: return '”' ;right double curly quote
                case 149: return '•' ;bullet point
                case 150: return '–' ;en dash
                case 151: return '—' ;em dash
                case 152: return '˜' ;spacing tilde diacritic, not ~
                case 153: return '™'
                case 154: return 'š'
                case 155: return '›' ;right single guillemet
                case 156: return 'œ'
                ;control character OSC
                case 158: return 'ž'
                case 159: return 'Ÿ'
                ;ANSI Chars coincide with Unicode other than those above.
                default:  return Chr(numberString)
            }
        } else {
            ;CP-437 codes that override the ASCII control chars, or those above 127
            switch (numberString){
                ;null char
                case 1:   return '☺'
                case 2:   return '☻'
                case 3:   return '♥'
                case 4:   return '♦'
                case 5:   return '♣'
                case 6:   return '♠'
                case 7:   return '•' ;bullet point
                case 8:   return '◘' ;inverted color bullet point
                case 9:   return '○' ;circle, not o
                case 10:  return '◙' ;inverted circle
                case 11:  return '♂'
                case 12:  return '♀'
                case 13:  return '♪'
                case 14:  return '♫' ;beamed eighth or sixteenth notes
                case 15:  return '☼' ;sun
                case 16:  return '►' ;right pointer
                case 17:  return '◄' ;left pointer
                case 18:  return '↕'
                case 19:  return '‼' ;double !
                case 20:  return '¶'
                case 21:  return '§'
                case 22:  return '▬' ;black rectangle
                case 23:  return '↨'
                case 24:  return '↑'
                case 25:  return '↓'
                case 26:  return '→'
                case 27:  return '←'
                case 28:  return '∟' ;right angle sign
                case 29:  return '↔'
                case 30:  return '▲' ;up pointer
                case 31:  return '▼' ;down pointer
                ;printable ASCII, coincides with Unicode; see default case
                case 127: return '⌂'
                case 128: return 'Ç'
                case 129: return 'ü'
                case 130: return 'é'
                case 131: return 'â'
                case 132: return 'ä'
                case 133: return 'à'
                case 134: return 'å'
                case 135: return 'ç'
                case 136: return 'ê'
                case 137: return 'ë'
                case 138: return 'è'
                case 139: return 'ï'
                case 140: return 'î'
                case 141: return 'ì'
                case 142: return 'Ä'
                case 143: return 'Å'
                case 144: return 'È'
                case 145: return "æ"
                case 146: return "Æ"
                case 147: return 'ô'
                case 148: return 'ö'
                case 149: return 'ò'
                case 150: return 'û'
                case 151: return 'ù'
                case 152: return 'ÿ'
                case 153: return 'Ö'
                case 154: return 'Ü'
                case 155: return '¢'
                case 156: return '£'
                case 157: return '¥'
                case 158: return '₧'
                case 159: return 'ƒ'
                case 160: return 'á'
                case 161: return 'í'
                case 162: return 'ó'
                case 163: return 'ú'
                case 164: return 'ñ'
                case 165: return 'Ñ'
                case 166: return 'ª' ;feminine ordinal indicator
                case 167: return 'º' ;masculine ordinal indicator
                case 168: return '¿'
                case 169: return '⌐' ;reversed negation
                case 170: return '¬' ;negation
                case 171: return '½'
                case 172: return '¼'
                case 173: return '¡'
                case 174: return '«'
                case 175: return '»'
                case 176: return '░' ;light shade
                case 177: return '▒' ;medium shade
                case 178: return '▓' ;dark shade
                case 179: return '│' ;box drawing single vertical
                case 180: return '┤'
                case 181: return '╡'
                case 182: return '╢'
                case 183: return '╖'
                case 184: return '╕'
                case 185: return '╣'
                case 186: return '║' ;box drawing double vertical
                case 187: return '╗'
                case 188: return '╝'
                case 189: return '╜'
                case 190: return '╛'
                case 191: return '┐' ;box drawing single top right corner
                case 192: return '└' ;box drawing single bottom left corner
                case 193: return '┴' ;box drawing single bottom t-pipe
                case 194: return '┬' ;box drawing single top t-pipe
                case 195: return '├'
                case 196: return '─' ;box drawing single horizontal
                case 197: return '┼' ;box drawing single intersection
                case 198: return '╞'
                case 199: return '╟'
                case 200: return '╚' ;box drawing double bottom left corner
                case 201: return '╔'
                case 202: return '╩'
                case 203: return '╦'
                case 204: return '╠'
                case 205: return '═' ;box drawing double horizontal
                case 206: return '╬'
                case 207: return '╧' ;box drawing double-single bottom t-pipe
                case 208: return '╨' ;box drawing single-double bottom t-pipe
                case 209: return '╤' ;box drawing double-single top t-pipe
                case 210: return '╥' ;box drawing single-double top t-pipe
                case 211: return '╙'
                case 212: return '╘'
                case 213: return '╒'
                case 214: return '╓'
                case 215: return '╫' ;box drawing single-double intersection
                case 216: return '╪' ;box drawing double-single intersection
                case 217: return '┘' ;box drawing single bottom right corner
                case 218: return '┌' ;box drawing single top left corner
                case 219: return '█' ;full cell
                case 220: return '▄' ;bottom half cell
                case 221: return '▌' ;left half cell
                case 222: return '▐' ;right half cell
                case 223: return '▀' ;top half cell
                case 224: return 'α' ;lowercase alpha
                case 225: return 'ß' ;sharp s
                case 226: return 'Γ' ;capital gamma
                case 227: return 'π' ;lowercase pi
                case 228: return 'Σ'
                case 229: return 'σ' ;lowercase sigma
                case 230: return 'µ' ;micro sign
                case 231: return 'τ'
                case 232: return 'Φ'
                case 233: return 'Θ'
                case 234: return 'Ω'
                case 235: return 'δ'
                case 236: return '∞'
                case 237: return 'φ' ;lowercase phi, not always straight phi.
                case 238: return 'ε' ;lowercase epsilon
                case 239: return '∩'
                case 240: return '≡'
                case 241: return '±'
                case 242: return '≥'
                case 243: return '≤'
                case 244: return '⌠' ;integral sign top half
                case 245: return '⌡' ;integral sign bottom half
                case 246: return '÷'
                case 247: return '≈'
                case 248: return '°' ;degree sign
                case 249: return '∙' ;bullet operator, such as multiplication
                case 250: return '·' ;middle dot, such as interpunct
                case 251: return '√' ;sqrt sign
                case 252: return 'ⁿ' ;superscript n
                case 253: return '²' ;squared sign
                case 254: return '■' ;black square
                case 255: return ' ' ;nonbreaking space
                ;just give unicode characters for printable ASCII, same codes
                default:  return Chr(numberString)
            }
        }
    ;characters ≥ 256 give you the corresponding unicode character
    ;printable ascii range (32-126) gives you the same character as unicode
    } else {
        return Chr(numberString)
    }
}
