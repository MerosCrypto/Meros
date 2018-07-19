import sets
import strutils

#Exponentiation of a function.
#f^n(x) = f(f(f(... n times ... f(f(f(x))))))
proc `^`*[T](f: proc(x: T): T, power: int): proc(x: T): T {.raises: [Exception].} =
  return proc(x: T): T {.raises: [Exception].} =
    result = x
    for _ in 1 .. power:
      result = f(result)

func `[]`*[T](o: OrderedSet[T], loc: int): T =
  if loc >= len(o):
    raise newException(ValueError, "$# out of range!" % $loc)
  for i, item in o:
    if i == loc:
      return item
