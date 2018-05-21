type UInt* = ref object of RootObj
    number: string

proc `$`*(x: UInt): string =
    result = x.number

proc verify*(number: string) =
    var ascii: int
    for i in 0 ..< number.len:
        ascii = (int) number[i]
        if 47 < ascii and ascii < 58:
            discard
        else:
            echo number
            raise newException(Exception, "Invalid Decimal Number")

proc clean*(number: UInt) =
    while number.number[0] == '0':
        if number.number.len == 1:
            break
        number.number = number.number.substr(1, number.number.len)

proc newUInt*(number: string): UInt =
    verify(number)
    result = UInt(
        number: number
    )
    result.clean()
