proc `+`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = xArg
        y: UInt = yArg

    result = newUInt("")
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    var
        len: int = x.number.len
        ascii0: int = (int) '0'
        xVal: int
        yVal: int
        zVal: int = 0
        asciiCode: int

    for i in 1 .. len:
        xVal = ((int) x.number[len-i]) - ascii0
        yVal = ((int) y.number[len-i]) - ascii0
        xVal = xVal + yVal + zVal
        if xVal >= 10:
            xVal = xVal - 10
            zVal = 1
        else:
            zVal = 0
        asciiCode = xVal + ascii0
        result.number = $((char) asciiCode) & result.number
    if zVal == 1:
        result.number = "1" & result.number
