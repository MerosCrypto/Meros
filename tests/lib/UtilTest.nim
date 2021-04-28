import random
import strutils

import ../../src/lib/Util

import ../Fuzzed

const
  MAXI8: int = high(int8)
  MAXU8: int = int(not byte(0))
  MAXI16: int = high(int16)
  MAXU16: int = int(not uint16(0))
  MAXI32: int = high(int32)

when sizeof(int) == 8:
  const MAXU32: int = int(not uint32(0))

suite "Util":
  noFuzzTest "Make sure leading 0 bytes are ignored.":
    check:
      0.toBinary() == ""
      "\0\0\0\0".fromBinary() == 0

  noFuzzTest "char fromBinary behaves the same as string fromBinary.":
    var r: int = rand(255)
    check char(r).fromBinary() == ($char(r)).fromBinary()

  midFuzzTest "int8 serialization/parsing.":
    var i8: int8 = int8(rand(MAXI8))
    check i8 == int8(i8.toBinary().fromBinary())

  midFuzzTest "byte serialization/parsing.":
    var u8: byte = byte(rand(MAXU8))
    check u8 == byte(u8.toBinary().fromBinary())

  midFuzzTest "int16 serialization/parsing.":
    var i16: int16 = int16(rand(MAXI16))
    check i16 == int16(i16.toBinary().fromBinary())

  midFuzzTest "uint16 serialization/parsing.":
    var u16: uint16 = uint16(rand(MAXU16))
    check u16 == uint16(u16.toBinary().fromBinary())

  midFuzzTest "int32 serialization/parsing.":
    var i32: int32 = int32(rand(MAXI32))
    check i32 == int32(i32.toBinary().fromBinary())

  when sizeof(int) == 8:
    midFuzzTest "uint32 serialization/parsing.":
      var u32: uint32 = uint32(rand(MAXU32))
      check u32 == uint32(u32.toBinary().fromBinary())

  noFuzzTest "An extremely high number (21 million Meros).":
    var u64: uint64 = uint64(210000000000000000)
    check u64 == uint64(u64.toBinary().fromBinary())

  noFuzzTest "The same number yet with the Nim standard lib.":
    var u64: uint64 = uint64(210000000000000000)
    check u64 == uint64(parseUInt($u64))
