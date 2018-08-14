#Wrapper around stint.

import stint

type
    #Wrapper object.
    BN* = ref object of RootObj
        number: StUint[1024]

    #Some basic numbers to stop hard coded BN literals.
    BNNumsType* = ref object of RootObj
        ZERO*: BN
        ONE*:  BN
        TWO*:  BN
        TEN*:  BN
        HIGH*: BN

#Stringify function.
proc `$`*(x: BN): string {.raises: [ValueError].} =
    try:
        result = $x.number
    except DivByZeroError:
        raise newException(ValueError, "Divide by zero.")

#Nim constructor from a string/nothing.
proc newBN*(number: string = "0"): BN {.raises: [].} =
    result = BN()
    result.number = number.parse(StUint[1024])

#Nim constructor from a number.
proc newBN*(number: SomeInteger): BN {.raises: [].} =
    result = BN()
    result.number = number.stuint(1024)

#Define some basic numbers.
var BNNums*: BNNumsType = BNNumsType(
    ZERO: newBN("0"),
    ONE:  newBN("1"),
    TWO:  newBN("2"),
    TEN:  newBN("10"),
    HIGH: newBN(int.high)
)

#Addition function.
proc `+`*(x: BN, y: BN): BN {.raises: [].} =
    result = BN()
    result.number = x.number + y.number

#+= operator.
proc `+=`*(x: var BN, y: BN) {.raises: [].} =
    x.number = (x + y).number

#Nim uses inc/dec instead of ++ and --. This is when BNNums is useful as hell.
proc inc*(x: var BN) {.raises: [].} =
    x += BNNums.ONE

#Subtraction function.
proc `-`*(x: BN, y: BN): BN {.raises: [].} =
    result = BN()
    result.number = x.number - y.number

#-= operator.
proc `-=`*(x: var BN, y: BN) {.raises: [].} =
    x.number = (x - y).number

proc dec*(x: var BN) {.raises: [].} =
    x -= BNNums.ONE

#Multiplication function.
proc `*`*(x: BN, y: BN): BN {.raises: [].} =
    result = BN()
    result.number = x.number * y.number

proc `*=`*(x: var BN, y: BN) {.raises: [].} =
    x.number = (x * y).number

#Exponent/power function.
proc `^`*(x: BN, y: BN): BN {.raises: [].} =
    result = BN()
    result.number = x.number.pow(y.number)

proc `pow`*(x: BN, y: BN): BN {.raises: [].} =
    x ^ y

#Division function.
proc `/`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    result = newBN()
    try:
        result.number = x.number div y.number
    except DivByZeroError:
        raise newException(ValueError, "Divide by zero.")

proc `div`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    x / y

#Modulus function.
proc `%`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    result = newBN()
    try:
        result.number = x.number mod y.number
    except DivByZeroError:
        raise newException(ValueError, "Divide by zero.")

proc `mod`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    x % y

#All of the comparison functions. ==, !-, <, <=, >, and >=.
proc `==`*(x: BN, y: BN): bool {.raises: [].} =
    x.number == y.number

proc `!=`*(x: BN, y: BN): bool {.raises: [].} =
    x.number != y.number

proc `<`*(x: BN, y: BN): bool {.raises: [].} =
    x.number < y.number

proc `<=`*(x: BN, y: BN): bool {.raises: [].} =
    x.number <= y.number

proc `>`*(x: BN, y: BN): bool {.raises: [].} =
    x.number > y.number

proc `>=`*(x: BN, y: BN): bool {.raises: [].} =
    x.number >= y.number

#To int function.
proc toInt*(x: BN): int {.raises: [ValueError].} =
    if x > BNNums.HIGH:
        raise newException(ValueError, "BN is too big to be converted to an int")

    result = x.number.toInt()
