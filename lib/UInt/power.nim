proc `^`*(x: UInt, yArg: UInt): UInt =
    result = num1
    var y: UInt = yArg #Don't touch the original
    while y > num0:
        result = result * x
        dec(y)
        
proc pow*(x: UInt, y: UInt): UInt =
    result = x ^ y
