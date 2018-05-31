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

    result.clean()
