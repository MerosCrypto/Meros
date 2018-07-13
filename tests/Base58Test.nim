import ../src/lib/BN
import ../src/lib/Base58

var Base58Characters: array[0 .. 57, char] = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J',
    'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
    'j', 'k', 'm', 'n', 'o', 'p', 'q', 'r', 's',
    't', 'u', 'v', 'w', 'x', 'y', 'z'
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

    temp = Base58.convert(newBN(pair.value))
    if (pair.target != nil) and (pair.target != temp):
        result = "Conerted to " & temp & "."
        return

    temp = $Base58.revert(temp)
    if pair.value != temp:
        result = "Reverted to " & temp & "."
        return

proc suite*(): string =
    var pairs: seq[PairObj] = @[
        Pair("58", "21"),
        Pair("59", "22"),
        Pair("131", "3G")
    ]

    for i in 0 ..< Base58Characters.len:
        pairs.add(
            Pair($i, $Base58Characters[i])
        )

    for pair in pairs:
        result = test(pair)
        if result != "":
            result =
                "Base 58 Test with a value of: " & pair.value &
                " and target of: " & pair.target &
                " failed. Error: " & result
            return

    result = ""

when isMainModule:
    var res: string = suite()
    if res == "":
        echo "Success"
    else:
        echo res
