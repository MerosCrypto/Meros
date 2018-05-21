proc `==`*(x: UInt, y: UInt): bool =
    result = x.number == y.number

proc `!=`*(x: UInt, y: UInt): bool =
    result = x.number != y.number
