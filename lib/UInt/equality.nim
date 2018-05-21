proc `==`*(x: UInt, y: UInt): bool =
    x.clean()
    y.clean()
    result = x.number == y.number

proc `!=`*(x: UInt, y: UInt): bool =
    result = not (x.number == y.number)
