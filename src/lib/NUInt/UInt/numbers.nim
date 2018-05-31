type UIntNumsType* = ref object of RootObj
    ZERO*: UInt
    ONE*: UInt
    TWO*: UInt
    TEN*: UInt
    SIXTEEN*: UInt
    FIFTYEIGHT*: UInt

var UIntNums*: UIntNumsType = UIntNumsType(
    ZERO: newUInt("0"),
    ONE: newUInt("1"),
    TWO: newUInt("2"),
    TEN: newUInt("10"),
    SIXTEEN: newUInt("16"),
    FIFTYEIGHT: newUInt("58")
)
