proc `/`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)
        thisLoop: int
    result = newUInt(UIntNums.ZERO.number)

    while x > yArg:
        y = yArg
        thisLoop = 1
        while true:
            try:
                discard x - (y * UIntNums.TWO)
            except:
                break
            y = y * UIntNums.TWO
            thisLoop = thisLoop * 2
        x = x - y
        result = result + newUInt($thisLoop)

proc `div`*(x: UInt, y: UInt): UInt =
    result = x / y
