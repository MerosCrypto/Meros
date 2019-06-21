#Util lib.
import ../../src/lib/Util

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    #Make sure leading 0 bytes are ignored.
    assert(0.toBinary() == "")
    assert("\0\0\0\0".fromBinary() == 0)

    #Test char fromBinary behaves the same as string fromBinary.
    for i in 0 .. 2555:
        assert(char(i).fromBinary() == ($char(i)).fromBinary())

    #Get the maximum value for each bit size.
    const
        MAXI8: int = high(int8)
        MAXU8: int = int(not uint8(0))
        MAXI16: int = high(int16)
        MAXU16: int = int(not uint16(0))
        MAXI32: int = high(int32)
        MAXU32: int = int(not uint32(0))

    #Test int8 serialization/parsing,
    for _ in 0 .. 255:
        var i8: int8 = int8(rand(MAXI8))
        assert(i8 == int8(i8.toBinary().fromBinary()))

    #Test uint8 serialization/parsing,
    for _ in 0 .. 255:
        var u8: uint8 = uint8(rand(MAXU8))
        assert(u8 == uint8(u8.toBinary().fromBinary()))

    #Test int16 serialization/parsing,
    for _ in 0 .. 255:
        var i16: int16 = int16(rand(MAXI16))
        assert(i16 == int16(i16.toBinary().fromBinary()))

    #Test uint16 serialization/parsing,
    for _ in 0 .. 255:
        var u16: uint16 = uint16(rand(MAXU16))
        assert(u16 == uint16(u16.toBinary().fromBinary()))

    #Test int32 serialization/parsing,
    for _ in 0 .. 255:
        var i32: int32 = int32(rand(MAXI32))
        assert(i32 == int32(i32.toBinary().fromBinary()))

    #Test uint32 serialization/parsing,
    for _ in 0 .. 255:
        var u32: uint32 = uint32(rand(MAXU32))
        assert(u32 == uint32(u32.toBinary().fromBinary()))

    #Test an extremely high number (21 million Meros).
    var u64: uint64 = uint64(210000000000000000)
    assert(u64 == uint64(u64.toBinary().fromBinary()))

    #Test the same number yet with the Nim standard lib.
    assert(u64 == uint64(parseUInt($u64)))

    echo "Finished the lib/Util Test."
