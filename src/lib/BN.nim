#Wrapper around GMP.
import gmp
import gmp/utils

type
    #Wrapper object.
    BN* = ref object of RootObj
        number: mpz_t

    #Some basic numbers to stop hard coded BN literals.
    BNNumsType* = ref object of RootObj
        ZERO*:     BN
        ONE*:      BN
        TWO*:      BN
        TEN*:      BN
        HUNDRED*:  BN
        HIGH*:     BN

#Stringify function.
proc `$`*(x: BN): string {.raises: [].} =
    result = $x.number

#Nim constructor from a string/nothing.
proc newBN*(number: string = "0"): BN {.raises: [ValueError].} =
    result = BN()
    result.number = init_mpz(number, 10)

#Nim constructor from a number.
proc newBN*(number: SomeInteger): BN {.raises: [].} =
    result = BN()
    result.number = number

#Nim constructor from a BN.
proc newBN*(number: BN): BN {.raises: [].} =
    result = BN()
    result[] = number[]

#Define some basic numbers.
var BNNums*: BNNumsType = BNNumsType(
    ZERO:     newBN(0),
    ONE:      newBN(1),
    TWO:      newBN(2),
    TEN:      newBN(10),
    HUNDRED:  newBN(100),
    HIGH:     newBN(int.high)
)

#Addition function.
proc `+`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    result = newBN()
    mpz_add(result.number, x.number, y.number)

#+= operator.
proc `+=`*(x: var BN, y: BN) {.raises: [ValueError].} =
    x.number = (x + y).number

#Nim uses inc/dec instead of ++ and --. This is when BNNums is useful as hell.
proc inc*(x: var BN) {.raises: [ValueError].} =
    x += BNNums.ONE

#Subtraction function.
proc `-`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    result = newBN()
    mpz_sub(result.number, x.number, y.number)

#-= operator.
proc `-=`*(x: var BN, y: BN) {.raises: [ValueError].} =
    x.number = (x - y).number

proc dec*(x: var BN) {.raises: [ValueError].} =
    x -= BNNums.ONE

#Multiplication function.
proc `*`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    result = newBN()
    mpz_mul(result.number, x.number, y.number)

proc `*=`*(x: var BN, y: BN) {.raises: [ValueError].} =
    x.number = (x * y).number

#Exponent/power function.
proc `^`*(x: BN, y: SomeInteger): BN {.raises: [ValueError].} =
    result = newBN()
    mpz_pow_ui(result.number, x.number, (culong) y)

proc `pow`*(x: BN, y: SomeInteger): BN {.raises: [].} =
    x ^ y

#Division function.
proc `/`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    if y.number == BNNums.ZERO.number:
        raise newException(ValueError, "Divide by zero.")

    result = newBN()
    mpz_fdiv_q(result.number, x.number, y.number)

proc `div`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    x / y

#Modulus function.
proc `%`*(x: BN, y: BN): BN {.raises: [ValueError].} =
    if y.number == BNNums.ZERO.number:
        raise newException(ValueError, "Divide by zero.")

    result = newBN()
    mpz_mod(result.number, x.number, y.number)

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

    result = mpz_get_si(x.number)
