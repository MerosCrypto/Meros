proc `mod`*(xArg: UInt, yArg: UInt): UInt =
    var y: UInt
    result = xArg
    while result > yArg:
        y = yArg
        while true:
            try:
                discard result - (y * UIntNums.TWO)
            except:
                break
            y = y * UIntNums.TWO
        result = result - y
