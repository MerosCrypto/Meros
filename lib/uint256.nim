#Empty file. Just details all the needed functions and the uint256 type.

type uint256* = ref object of RootObj

proc init*(source: uint256, value: string)

proc `+`*(x: uint256, y: uint256): uint256
proc `-`*(x: uint256, y: uint256): uint256
proc `*`*(x: uint256, y: uint256): uint256
proc `/`*(x: uint256, y: uint256): uint256

proc `div`*(x: uint256, y: uint256): uint256 =
    result = x / y

proc `+=`*(x: uint256, y: uint256): uint256
proc `-=`*(x: uint256, y: uint256): uint256
proc `mod`*(x: uint256, y: uint256): uint256

proc `<`*(x: uint256, y: uint256): bool
proc `<=`*(x: uint256, y: uint256): bool

proc `>`*(x: uint256, y: uint256): bool
proc `>=`*(x: uint256, y: uint256): bool

proc `==`*(x: uint256, y: uint256): bool
proc `!=`*(x: uint256, y: uint256): bool
