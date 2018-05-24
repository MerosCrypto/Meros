proc `+=`*(x: UInt, y: UInt) =
    x.number = (x + y).number

proc `-=`*(x: UInt, y: UInt) =
    x.number = (x - y).number
    
proc `*=`*(x: UInt, y: UInt) =
    x.number = (x * y).number
