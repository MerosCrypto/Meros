proc `^`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = xArg
        y: UInt = yArg
    result = newUInt(UIntNums.ONE.number)
    while y > UIntNums.ZERO:
        result = result * x
        dec(y)

    result.clean()

proc pow*(x: UInt, y: UInt): UInt =
    result = x ^ y
