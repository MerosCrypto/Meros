proc `^`*[T](f: proc(x: T): T, power: int): proc(x: T): T =
    ## "Exponentiation" of a function
    ## (f^n)(x) := f(f(f( ... n times ... f(f(f(x))) ... )))
    return proc(x: T): T =
        result = x
        for _ in 1 .. power:
            result = f(result)

when isMainModule:
    func double(x: int): int =
        return x * 2

    assert (double^0)(3) == 3
    assert (double^1)(4) == 8
    assert (double^2)(3) == 12

