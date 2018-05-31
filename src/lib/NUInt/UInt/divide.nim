proc `/`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt
        thisLoop: UInt
    result = newUInt(UIntNums.ZERO.number)

    while x >= yArg:
        y = newUInt(yArg.number)
        thisLoop = newUInt(UIntNums.ONE.number)
        while true:
            try:
                discard x - (y * UIntNums.TWO)
            except:
                break
            y = y * UIntNums.TWO
            thisLoop = thisLoop * UIntNums.TWO
        x = x - y
        result = result + thisLoop

proc `div`*(x: UInt, y: UInt): UInt =
    result = x / y
