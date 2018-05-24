import strutils, math

type
    BN* = ref object of RootObj
        number: uint64

proc newBN*(number: string): BN =
    result = BN()
    result.number = (uint64) parseUInt(number)

proc `$`*(x: BN): string =
    result = $x.number

proc `+`*(x: BN, y: BN): BN =
    result = newBN($(x.number + y.number))
proc `+=`*(x: BN, y: BN) =
    x.number += y.number

proc inc*(x: BN) =
    x.number += uint64(1)

proc `-`*(x: BN, y: BN): BN =
    result = newBN($(x.number - y.number))
proc `-=`*(x: BN, y: BN) =
    x.number -= y.number
proc dec*(x: BN) =
    x.number -= uint64(1)

proc `*`*(x: BN, y: BN): BN =
    result = newBN($(x.number * y.number))
proc `*=`*(x: BN, y: BN) =
    x.number *= y.number

proc `^`*(x: BN, y: BN): BN =
    result = newBN($(x.number ^ y.number))
proc `pow`*(x: BN, y: BN): BN =
    result = x ^ y

proc `/`*(x: BN, y: BN): BN =
    result = newBN($(x.number div y.number))
proc `div`*(x: BN, y: BN): BN =
    result = x / y

proc `%`*(x: BN, y: BN): BN =
    result = newBN($(x.number mod y.number))
proc `mod`*(x: BN, y: BN): BN =
    result = x % y

proc `==`*(x: BN, y: BN): bool =
    result = x.number == y.number
proc `!=`*(x: BN, y: BN): bool =
    result = x.number != y.number

proc `<`*(x: BN, y: BN): bool =
    result = x.number < y.number
proc `<=`*(x: BN, y: BN): bool =
    result = x.number <= y.number
proc `>`*(x: BN, y: BN): bool =
    result = x.number > y.number
proc `>=`*(x: BN, y: BN): bool =
    result = x.number >= y.number

type BNNumsType* = ref object of RootObj
    ZERO*: BN
    ONE*: BN
    TWO*: BN
    TEN*: BN
    SIXTEEN*: BN
    FIFTYEIGHT*: BN

var BNNums*: BNNumsType = BNNumsType(
    ZERO: newBN("0"),
    ONE: newBN("1"),
    TWO: newBN("2"),
    TEN: newBN("10"),
    SIXTEEN: newBN("16"),
    FIFTYEIGHT: newBN("58")
)
