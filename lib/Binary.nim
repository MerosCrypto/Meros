type Binary* = ref object of RootObj
    number: string

proc verify*(binaryValue: string) =
    for i in 0 ..< binaryValue.len:
        if binaryValue[i] == '0':
            discard
        elif binaryValue[i] == '1':
            discard
        else:
            raise newException(Exception, "Invalid Binary Number")

proc newBinary*(number: string): Binary =
    verify(number)
    result = Binary(
        number: number
    )

proc `+`*(x: Binary, y: Binary): Binary =
    result = newBinary("")
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    var
        len: int = x.number.len
        ascii0: int = (int) '0'
        asciiX: int
        asciiY: int
        asciiCode: int
    for i in 1 .. len:
        if result.number[0] == '2':
            result.number[0] = '0'
            result.number = "1" & result.number
        elif result.number[0] == '3':
            result.number[0] = '1'
            result.number = "1" & result.number
        else:
            result.number = "0" & result.number

        asciiX = (int) x.number[len-i]
        asciiY = (int) y.number[len-i]
        asciiCode = (int) result.number[0]
        asciiCode = asciiCode + asciiX - ascii0 + asciiY - ascii0
        result.number[0] = (char) asciiCode

    if result.number[0] == '2':
        result.number[0] = '0'
        result.number = "1" & result.number
    elif result.number[0] == '3':
        result.number[0] = '1'
        result.number = "1" & result.number

proc `-`*(x: Binary, y: Binary): Binary =
    result = newBinary("")
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number

    var
        len: int = x.number.len
        z: int
    for i in 1 .. len:
        if x.number[len-i] == y.number[len-i]:
            result.number = "0" & result.number
        elif x.number[len-i] == '1':
            result.number = "1" & result.number
        elif y.number[len-i] == '1':
            result.number = "1" & result.number
            z = i
            while x.number[len-z] != '1':
                if len - z == 0:
                    raise newException(Exception, "Negative Overflow Error")
                inc(z)
            x.number[len-z] = '0'
            while z > i:
                dec(z)
                x.number[len-z] = '1'

    while result.number[0] == '0':
        if result.number.len == 1:
            break
        result.number = result.number.substr(1, result.number.len)

proc `*`*(x: Binary, y: Binary): Binary =
    result = newBinary("0")
    while y.number != "0":
        result = result + x

proc `/`*(xArg: Binary, y: Binary): Binary =
    var
        x: Binary = xArg
        noError: bool = true
    result = newBinary("0")
    while noError:
        try:
            x = x - y
        except:
            noError = false
            break
        result = result + newBinary("1")
proc `div`*(x: Binary, y: Binary): Binary =
    result = x / y

proc `+=`*(x: Binary, y: Binary) =
    x.number = (x + y).number
proc `-=`*(x: Binary, y: Binary) =
    x.number = (x - y).number

proc `mod`*(xArg: Binary, y: Binary): Binary =
    var
        x: Binary = xArg
        noError: bool = true
    result = newBinary("0")
    while noError:
        try:
            x = x - y
        except:
            noError = false
            break
        result = x

    while result.number[0] == '0':
        if result.number.len == 1:
            break
        result.number = result.number.substr(1, result.number.len)

proc `==`*(x: Binary, y: Binary): bool =
    result = x.number == y.number
proc `!=`*(x: Binary, y: Binary): bool =
    result = x.number != y.number

proc `<`*(x: Binary, y: Binary): bool =
    while x.number.len < y.number.len:
        x.number = "0" & x.number
    while y.number.len < x.number.len:
        y.number = "0" & y.number
    for i in 0 ..< x.number.len:
        echo ((int) x.number[i])
        echo ((int) y.number[i])
        if ((int) x.number[i]) < ((int) y.number[i]):
            result = true
            return
    result = false
proc `<=`*(x: Binary, y: Binary): bool =
    result = (x < y) or (x == y)

proc `>`*(x: Binary, y: Binary): bool =
    result = y < x
proc `>=`*(x: Binary, y: Binary): bool =
    result = (x > y) or (x == y)

proc `$`*(x: Binary): string =
    result = x.number
