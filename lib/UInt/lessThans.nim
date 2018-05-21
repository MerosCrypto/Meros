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
