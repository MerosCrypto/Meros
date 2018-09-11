#Exponentiation of a function.
#f^n(x) = f(f(f(... n times ... f(f(f(x))))))
proc `^`*[T](f: proc(x: T): T, power: int): proc(x: T): T {.raises: [Exception].} =
    result = proc(x: T): T {.raises: [Exception].} =
        result = x
        for _ in 1 .. power:
            result = f(result)

#Pads a string with a prefix to be a certain length.
proc pad*(data: string, len: int, prefix: string = "0"): string {.raises: [].} =
    result = data
    while result.len < len:
        result = prefix & result
