proc `*`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)

    var factor: UInt = y
    result = num0
    while factor.number != "0":
        result = result + x
        factor = factor - num1
