#Nim wrapper around the imath C library.

#Also compile the imath C file.
{.compile: "../../src/lib/BN/imath.c".}

import strutils, math

type
    #Direct copy of the imath BN struct.
    mpz_t {.bycopy.} = object
        single: cuint
        digits: ptr cuint
        alloc: cuint
        used: cuint
        sign: cuchar

    #Wrapper object.
    BN* = ref object of RootObj
        number: mpz_t

    #Some basic numbers to stop hard coded BN literals.
    BNNumsType* = ref object of RootObj
        ZERO*: BN
        ONE*: BN
        TWO*: BN
        TEN*: BN
        SIXTEEN*: BN
        FIFTYEIGHT*: BN

#C 'constructor'.
proc mpz_tInit(x: ptr mpz_t, base: cint, value: cstring) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_read_string".}
#Nim constructors.
proc newBN*(): BN {.raises: [].} =
    result = BN()

    var default: string = "0"
    mpz_tInit(addr result.number, 10, addr default[0])
proc newBN*(numberArg: string): BN {.raises: [].} =
    result = BN()

    var number: string = numberArg
    mpz_tInit(addr result.number, 10, addr number[0])
proc newBN*(number: SomeInteger): BN {.raises: [].} =
    result = newBN($number)

#Define some basic numbers.
var BNNums*: BNNumsType = BNNumsType(
    ZERO: newBN("0"),
    ONE: newBN("1"),
    TWO: newBN("2"),
    TEN: newBN("10"),
    SIXTEEN: newBN("16"),
    FIFTYEIGHT: newBN("58")
)

#Stringify function.
proc mpz_tStringify(x: ptr mpz_t): cstring {.header: "../../src/lib/BN/wrapper.h", importc: "printMPZ_T".}
proc `$`*(x: BN): string {.raises: [].} =
    result = $mpz_tStringify(addr x.number)

#Addition  function.
proc mpz_tAdd(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_add".}
proc `+`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    mpz_tAdd(addr x.number, addr y.number, addr result.number)
#+= operator.
proc `+=`*(x: BN, y: BN) {.raises: [].} =
    x.number = (x + y).number
#Nim uses inc/dec instead of ++ and --. This is when BNNums is useful as hell.
proc inc*(x: BN) {.raises: [].} =
    x += BNNums.ONE

#Subtraction functions.
proc mpz_tSub(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_sub".}
proc `-`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    mpz_tSub(addr x.number, addr y.number, addr result.number)
proc `-=`*(x: BN, y: BN) {.raises: [].} =
    x.number = (x - y).number
proc dec*(x: BN) {.raises: [].} =
    x -= BNNums.ONE

#Multiplication functions.
proc mpz_tMul(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_mul".}
proc `*`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    mpz_tMul(addr x.number, addr y.number, addr result.number)
proc `*=`*(x: BN, y: BN) {.raises: [].} =
    x.number = (x * y).number

#Exponent/power functions.
proc mpz_tPow(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_expt_full".}
proc `^`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    mpz_tPow(addr x.number, addr y.number, addr result.number)
proc `pow`*(x: BN, y: BN): BN {.raises: [].} =
    result = x ^ y

#Division functions.
proc mpz_tDiv(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t, r: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_div".}
proc `/`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    #imath also returns the remainder. We don't use it, hence the junk `addr newBN().number`.
    mpz_tDiv(addr x.number, addr y.number, addr result.number, addr newBN().number)
proc `div`*(x: BN, y: BN): BN {.raises: [].} =
    result = x / y

proc `//`*(x: BN, y: BN): tuple[result: BN, remainder: BN] {.raises: [].} =
    result.result = newBN()
    result.remainder = newBN()
    mpz_tDiv(addr x.number, addr y.number, addr result.result.number, addr result.remainder.number)
    return result
proc `divWRemainder`*(x: BN, y: BN): tuple[result: BN, remainder: BN] {.raises: [].} =
    result = x // y

#Modulus functions.
proc mpz_tMod(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../../src/lib/BN/imath.h", importc: "mp_int_mod".}
proc `%`*(x: BN, y: BN): BN {.raises: [].} =
    result = newBN()
    mpz_tMod(addr x.number, addr y.number, addr result.number)
proc `mod`*(x: BN, y: BN): BN {.raises: [].} =
    result = x % y

#All the comparison functions. ==, !-, <, <=, >, and >=.
proc mpz_tCompare(x: ptr mpz_t, y: ptr mpz_t): int {.header: "../../src/lib/BN/imath.h", importc: "mp_int_compare".}
proc `==`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) == 0
proc `!=`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) != 0
proc `<`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) == -1
proc `<=`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) != 1
proc `>`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) == 1
proc `>=`*(x: BN, y: BN): bool {.raises: [].} =
    result = mpz_tCompare(addr x.number, addr y.number) != -1
