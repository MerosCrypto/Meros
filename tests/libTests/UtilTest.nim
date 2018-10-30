#Util lib.
import ../../src/lib/Util

import strutils

#Various number types.
var
    i8: int8 = int8(73)
    u8: uint8 = uint8(156)
    i16: int16 = int16(16920)
    u16: uint16 = uint16(45198)
    i32: int32 = int32(98194)
    u32: uint32 = uint32(3631343648)

#Test the conversions work.
assert(i8 == int8(i8.toBinary().fromBinary()))
assert(u8 == uint8(u8.toBinary().fromBinary()))
assert(i16 == int16(i16.toBinary().fromBinary()))
assert(u16 == uint16(u16.toBinary().fromBinary()))
assert(i32 == int32(i32.toBinary().fromBinary()))
assert(u32 == uint32(u32.toBinary().fromBinary()))

#Make sure that leading 0 bytes are ignored.
assert(0.toBinary() == "")
