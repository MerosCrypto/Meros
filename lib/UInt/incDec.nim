proc inc*(x: UInt) =
    x += UIntNums.ONE

proc dec*(x: UInt)  =
    if x == UIntNums.ZERO:
        return

    x -= UIntNums.ONE
