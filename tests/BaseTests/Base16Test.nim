import BN
import ../../src/lib/Base

var HexCharacters: array[16, char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F'
]

type PairObj = object
    value: string
    target: string
proc Pair(value: string, target: string): PairObj =
    result = PairObj(
        value: value,
        target: target
    )

var temp: string
proc test(pair: PairObj): string =
    result = ""

    temp = newBN(pair.value).toString(16)
    if (pair.target != nil) and (pair.target != temp):
        result = "Converted to " & temp & "."
        return

    temp = $temp.toBN(16)
    if pair.value != temp:
        result = "Reverted to " & temp & "."
        return

proc suite*(): string =
    var pairs: seq[PairObj] = @[
        Pair("17", "11"),
        Pair("240", "F0"),
        Pair("255", "FF")
    ]

    for i in 0 ..< HexCharacters.len:
        var target = $HexCharacters[i]
        if (target.len mod 2) != 0:
            target = "0" & target
        pairs.add(
            Pair($i, target)
        )

    for pair in pairs:
        result = test(pair)
        if result != "":
            result =
                "Base16 Test with a value of: " & pair.value &
                " and target of: " & pair.target &
                " failed. Error: " & result
            return

    result = ""
