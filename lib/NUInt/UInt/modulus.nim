proc `mod`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt
    result = newUInt(x.number)
    while result >= yArg:
        y = yArg
        while true:
            try:
                discard result - (y * UIntNums.TWO)
            except:
                break
            y = y * UIntNums.TWO
        result = result - y

    result.clean()
