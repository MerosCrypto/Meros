proc `<`*(xArg: UInt, yArg: UInt): bool =
    xArg.clean()
    yArg.clean()
    
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)

    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    result = false
    for i in 0 ..< x.number.len:
        if ((int) x.number[i]) < ((int) y.number[i]):
            result = true
            return
        elif ((int) x.number[i]) == ((int) y.number[i]):
            discard
        else:
            return

proc `<=`*(x: UInt, y: UInt): bool =
    result = (x < y) or (x == y)
