{.compile: "../lib/BN/imath.c".}

import strutils, math

type
    mpz_t {.bycopy.} = object
        single: cuint
        digits: ptr cuint
        alloc: cuint
        used: cuint
        sign: cuchar

    BN* = ref object of RootObj
        number: mpz_t

    BNNumsType* = ref object of RootObj
        ZERO*: BN
        ONE*: BN
        TWO*: BN
        TEN*: BN
        SIXTEEN*: BN
        FIFTYEIGHT*: BN

proc mpz_tInit(x: ptr mpz_t, base: cint, value: cstring) {.header: "../lib/BN/imath.h", importc: "mp_int_read_string".}
proc newBN*(number: string = "0"): BN =
    result = BN()
    mpz_tInit(addr result.number, 10, (cstring) number)

var BNNums*: BNNumsType = BNNumsType(
    ZERO: newBN("0"),
    ONE: newBN("1"),
    TWO: newBN("2"),
    TEN: newBN("10"),
    SIXTEEN: newBN("16"),
    FIFTYEIGHT: newBN("58")
)

proc mpz_tStringify(x: ptr mpz_t): cstring {.header: "../lib/BN/wrapper.h", importc: "printMPZ_T".}
proc `$`*(x: BN): string =
    result = $mpz_tStringify(addr x.number)

proc mpz_tAdd(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_add".}
proc `+`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tAdd(addr x.number, addr y.number, addr result.number)
proc `+=`*(x: BN, y: BN) =
    x.number = (x + y).number
proc inc*(x: BN) =
    x += BNNums.ONE

proc mpz_tSub(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_sub".}
proc `-`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tSub(addr x.number, addr y.number, addr result.number)
proc `-=`*(x: BN, y: BN) =
    x.number = (x - y).number
proc dec*(x: BN) =
    x -= BNNums.ONE

proc mpz_tMul(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_mul".}
proc `*`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tMul(addr x.number, addr y.number, addr result.number)
proc `*=`*(x: BN, y: BN) =
    x.number = (x * y).number

proc mpz_tPow(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_expt_full".}
proc `^`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tPow(addr x.number, addr y.number, addr result.number)
proc `pow`*(x: BN, y: BN): BN =
    result = x ^ y

proc mpz_tDiv(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t, r: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_div".}
proc `/`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tDiv(addr x.number, addr y.number, addr result.number, addr newBN().number)
proc `div`*(x: BN, y: BN): BN =
    result = x / y

proc mpz_tMod(x: ptr mpz_t, y: ptr mpz_t, z: ptr mpz_t) {.header: "../lib/BN/imath.h", importc: "mp_int_mod".}
proc `%`*(x: BN, y: BN): BN =
    result = newBN()
    mpz_tMod(addr x.number, addr y.number, addr result.number)
proc `mod`*(x: BN, y: BN): BN =
    result = x % y

proc mpz_tCompare(x: ptr mpz_t, y: ptr mpz_t): int {.header: "../lib/BN/imath.h", importc: "mp_int_compare".}
proc `==`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) == 0
proc `!=`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) != 0
proc `<`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) == -1
proc `<=`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) != 1
proc `>`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) == 1
proc `>=`*(x: BN, y: BN): bool =
    result = mpz_tCompare(addr x.number, addr y.number) != -1
