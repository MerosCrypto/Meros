import sets

#Exponentiation of a function.
#f^n(x) = f(f(f(... n times ... f(f(f(x))))))
proc `^`*[T](f: proc(x: T): T, power: int): proc(x: T): T {.raises: [Exception].} =
    result = proc(x: T): T {.raises: [Exception].} =
        result = x
        for _ in 1 .. power:
            result = f(result)

#Return a specific element of an OrderSet by it's index.
proc `[]`*[T](oSet: OrderedSet[T], index: int): T {.raises: [ValueError].} =
    if index >= oSet.len:
        raise newException(ValueError, "OrderedSet index is out of range.")

    for i, item in oSet:
        if i == index:
            return item

proc pad*(data: string, len: int, prefix: string = "0"): string =
    result = data
    while result.len < len:
        result = prefix & result
