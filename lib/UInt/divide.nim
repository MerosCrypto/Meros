proc `/`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)
        thisLoop: int
    result = num0

    while x > yArg:
        y = yArg
        thisLoop = 1
        while true:
            try:
                discard x - (y * num2)
            except:
                break
            y = y * num2
            thisLoop = thisLoop * 2
        x = x - y
        result = result + newUInt($thisLoop)

proc `div`*(x: UInt, y: UInt): UInt =
    result = x / y
