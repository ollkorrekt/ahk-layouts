#Requires AutoHotkey v2.0

#include <array_binarySearchGap>
#include <array_toString>
#include <insertionSorted>
#include <sum>
;TODO document all functions
class Die {
    __New(sides := 6, custom := false){
        this.sides := sides
        this.custom := custom
    }

    roll(){
        if this.custom {
            i := Random(1, this.sides.Length)
            return this.sides[i]
        }
        return Random(1, this.sides)
    }
}

Coin() => Die([0,1], true)

class DiceNotation {
    __New(tag, data, args*){ 
        ;allowable notation tags:
        ;die - a single die
        ;const - a constant number
        ;op - a math op and two notes (you can multiply by 1 to "constify" after a certain step)
            ;possible ops include + - * /
        ;keep - a note and how many dice to keep from the highest and lowest of that note - keeping more than there are is noto valid.
        this.tag := tag
        this.data := data
        switch tag, "Off" {
        case "die", "dice":
            this.diceN := args.Get(1, 1) ;specified # of dice, or one die
            this.tag := "dice" ;normalize this tag
        case "const": this.diceN := 0
        case "op":
            this.left := args[1]
            this.right := args[2]
            if (data = "+") { ;I only care about addition here because otherwise keeping the dice doesn't make much sense, as they have already been messed with (even just with subtraction).
                this.diceN := this.left.diceN + this.right.diceN
            } else {
                this.diceN := 0
            }
        case "keep":
            this.high := args[1]
            this.low := args[2]
            this.diceN := this.high + this.low
            if (this.diceN > this.data.diceN){
                throw ValueError(Format(
                    "cannot keep {} out of {} dice.", 
                    this.diceN, this.data.diceN
                ), -1) ;note that this lets you keep all the dice, even though that's pointless.
            }
        default:
            throw ValueError(Format("{} is an invalid notation tag.", tag), -1)
        }
    }

    rolls(){
        switch this.tag {
        case "dice":
            dice := []
                loop this.diceN {
                    dice.push(this.data.roll())
                }
            return {dice: dice, const: 0}
        case "const": return {dice: [], const: this.data}
        case "op": 
            leftRolls := this.left.rolls()
            rightRolls := this.right.rolls()
            dice := []
            switch this.data {
            case "+":
                dice := leftRolls.dice.Clone()
                dice.push(rightRolls.dice*)
                const := leftRolls.const + rightRolls.const
            case "-":
                const := leftRolls.const - rightRolls.const
                    + sum(leftRolls.dice) - sum(rightRolls.dice)
            case "*":
                const := (leftRolls.const + sum(leftRolls.dice))
                      * (rightRolls.const + sum(rightRolls.dice))
            case "/":
                const := (leftRolls.const + sum(leftRolls.dice))
                    / (rightRolls.const + sum(rightRolls.dice))
            default:
                throw ValueError(Format("Invalid operation {}", this.data), -1) ;TODO move error checking to validation.
            }
            return {dice: dice, const: const}
        case "keep":
            oldRolls := this.data.rolls()
            oldDice := oldRolls.dice
            MsgBox(String(oldDice)) ;TODO delete this
            oldDice := insertionSorted(oldDice)
            newDice := oldDice.Clone() ;this will naturally make newDice's first values the lowest.
            newDice.Length := this.high + this.low
            Loop(this.high){ ;copy over the high values
                newDice[-A_Index] := oldDice[-A_Index]
            }
            return {dice: newDice, const: oldRolls.const}
        }
    }

    roll(){
        result := this.rolls()
        return sum(result.dice) + result.const
    }
}

parseDiceNotation(text){
    static opPattern := "
    (
    ix)^\s*+(?|
        ((?: (?&parens) | [^()]+ )+)
        ([+\-−])
        ((?: (?&parens) | [^()]+ )+)
    |
        ((?: (?&parens) | [^()]+ )+)
        ([*∗×⋅∙/⁄∕÷])
        ((?: (?&parens) | [^()]+ )+)
    `)\s*$
    (?(DEFINE) (?<parens>\( (?: [^()]++ | (?&parens) )++ \)) )
    )"
    static parenPattern := "ix)^\s*+\((.*)\)\s*$"
    static keepPattern := "ix)^\s*+(.*)(?:k\s*+h?\s*+(\d*)\s*+(?:l\s*+(\d*))?)\s*$"
    static dicePattern := "ix)^\s*+(\d*)\s*+d\s*+(\d+|F|C|%)\s*$"
    
    switch {
    case RegexMatch(text, opPattern, &match):
        left := match[1]
        op := match[2]
        right := match[3]
        switch op {
        case "−":
            op := "-"
        case "∗", "×", "⋅", "∙":
            op := "*"
        case "⁄", "∕", "÷":
            op := "/"
        }
        return DiceNotation("op", op, parseDiceNotation(left), parseDiceNotation(right))
    case RegexMatch(text, parenPattern, &match):
        return parseDiceNotation(match[1])
    case RegexMatch(text, keepPattern, &match):
        note := match[1]
        high := match[2] ? match[2] : 0
        low := match[3] ? match[3] : 0
        return DiceNotation("keep", parseDiceNotation(note), high, low)
    case RegexMatch(text, dicePattern, &match):
        n := match[1] ? match[1] : 1
        dieType := match[2]
        switch dieType, "Off" {
        case "F": thisDie := Die([-1,0,1], true)
        case "C": thisDie := Die([0,1], true)
        case "%": thisDie := Die(100)
        default: thisDie := Die(dieType) ;TODO how to represent an arbitrary die
        }
        return DiceNotation("dice", thisDie, n)
    default:
        try {
            const := Number(text)
        } catch TypeError {
            throw ValueError('unrecognized notation fragment: "' text '"')
        }
        return DiceNotation("const", const)
    }
}

/*TODO I want the script to have hotkeys to:
 * •roll highlighted note
 * •reroll prev. roll, maybe just if you highlight same text again? Maybe we
 * could use as a default the prev. notation, when no text is highlighted or
 * when the highlighted text is not a well-formed note, but in the latter case
 * it could be confusing to not notatify the user
 * •maybe open a dialog, like it does now?
 * but what to do on an error when not in dialog mode?
 */
n := parseDiceNotation(InputBox('enter notation').value)
x := n.roll()
MsgBox(x)

