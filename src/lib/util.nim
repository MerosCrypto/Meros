#Exponentiation of a function.
#f^n(x) = f(f(f(... n times ... f(f(f(x))))))
proc `^`*[T](f: proc(x: T): T, power: int): proc(x: T): T =
    return proc(x: T): T =
        result = x
        for _ in 1 .. power:
            result = f(result)
