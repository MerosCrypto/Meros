proc `mod`*(xArg: UInt, yArg: UInt): UInt =
    var y: UInt
    result = xArg
    while result > yArg:
        y = yArg
        while true:
            try:
                discard result - (y * num2)
            except:
                break
            y = y * num2
        result = result - y
