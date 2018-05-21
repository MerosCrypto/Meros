proc `^`*(x: UInt, yArg: UInt): UInt =
    result = newUInt(UIntNums.ONE.number)
    var y: UInt = yArg #Don't touch the original
    while y > UIntNums.ZERO:
        result = result * x
        dec(y)

proc pow*(x: UInt, y: UInt): UInt =
    result = x ^ y
