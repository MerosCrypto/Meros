proc `>`*(x: UInt, y: UInt): bool =
    result = y < x
    
proc `>=`*(x: UInt, y: UInt): bool =
    result = (x > y) or (x == y)
