type UInt* = ref object of RootObj
    number: string

proc `$`*(x: UInt): string =
    result = x.number

proc verify*(number: string) =
    var ascii: int
    for i in 0 ..< number.len:
        ascii = (int) number[i]
        if 47 < ascii and ascii < 58:
            discard
        else:
            raise newException(Exception, "Invalid Hex Number")

proc newUInt*(number: string): UInt =
    verify(number)
    result = UInt(
        number: number
    )

var
    num0: UInt = newUInt("0")
    num1: UInt = newUInt("1")
    num2: UInt = newUInt("2")

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

proc `-`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)

    result = newUInt("")
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    var
        len: int = x.number.len
        ascii0: int = (int) '0'
        z: int
        overflow: int
    for i in 1 .. len:
        if x.number[len-i] == y.number[len-i]:
            result.number = "0" & result.number
        elif ((int) x.number[len-i]) > ((int) y.number[len-i]):
            z = ((int) x.number[len-i]) - ((int) y.number[len-i])
            z = z + ascii0
            result.number = $((char) z) & result.number
        else:
            overflow = ((int) x.number[len-i]) - ((int) y.number[len-i]) + 10 + ascii0
            result.number = $((char) overflow) & result.number
            z = i
            inc(z)
            if len - z == -1:
                raise newException(Exception, "Negative Overflow Error")
            overflow = ((int) x.number[len-z]) - 1
            x.number[len-z] = (char) overflow
            while ((int) x.number[len-z]) == ascii0 - 1:
                x.number[len-z] = (char) ascii0 + 9
                inc(z)
                if len - z == -1:
                    raise newException(Exception, "Negative Overflow Error")
                overflow = ((int) x.number[len-z]) - 1
                x.number[len-z] = (char) overflow

    while result.number[0] == '0':
        if result.number.len == 1:
            break
        result.number = result.number.substr(1, result.number.len)

proc `*`*(x: UInt, y: UInt): UInt =
    var factor: UInt = y
    result = num0
    while factor.number != "0":
        result = result + x
        factor = factor - num1

proc `+=`*(x: UInt, y: UInt) =
    x.number = (x + y).number
proc `-=`*(x: UInt, y: UInt) =
    x.number = (x - y).number

proc `==`*(x: UInt, y: UInt): bool =
    result = x.number == y.number
proc `!=`*(x: UInt, y: UInt): bool =
    result = x.number != y.number

proc `<`*(x: UInt, y: UInt): bool =
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    for i in 0 ..< x.number.len:
        if ((int) x.number[i]) < ((int) y.number[i]):
            result = true
            return
    result = false
proc `<=`*(x: UInt, y: UInt): bool =
    result = (x < y) or (x == y)

proc `>`*(x: UInt, y: UInt): bool =
    result = y < x
proc `>=`*(x: UInt, y: UInt): bool =
    result = (x > y) or (x == y)

proc inc*(x: UInt) =
    x += num1
proc dec*(x: UInt)  =
    x -= num1

proc `^`*(x: UInt, yArg: UInt): UInt =
    result = num1
    var y: UInt = yArg #Don't touch the original
    while y > num0:
        result = result * x
        dec(y)
proc pow*(x: UInt, y: UInt): UInt =
    result = x ^ y

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

proc `/`*(xArg: UInt, yArg: UInt): UInt =
    var
        x: UInt = newUInt(xArg.number)
        y: UInt = newUInt(yArg.number)
        thisLoop: int
    result = num0

    echo $x
    echo $y
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
        echo "Division values:"
        echo $x
        echo $y
        x = x - y
        result = result + newUInt($thisLoop)
proc `div`*(x: UInt, y: UInt): UInt =
    result = x / y
