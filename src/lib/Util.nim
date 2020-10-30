import bitops
import times

import strutils
export toHex, parseHexStr, parseHexInt, parseUInt

import stint
import nimcrypto

#Manually import these to stop a recursive dependency.
import ForceCheck
import objects/ErrorObjs

#Gets the epoch and returns it.
proc getTime*(): uint32 {.inline, forceCheck: [].} =
  uint32(times.getTime().toUnix())

#Right pads data, with a char or string, until the data is a certain length.
func pad*(
  data: string,
  len: int,
  suffix: char or string = char(0)
): string {.forceCheck: [].} =
  result = $data
  var startLen: int = result.len
  result.setLen(max(result.len, len))
  for i in startLen ..< result.len:
    result[i] = suffix

#Reverse a string.
func reverse*(
  data: string
) : string {.forceCheck: [].} =
  result = newString(data.len)
  for i in 0 ..< data.len:
    result[data.len - 1 - i] = data[i]

#Convert a StUInt to hex, pruning leading 0 bytes.
func toShortHex*[bits: static int](
  x: StUInt[bits]
): string {.forceCheck: [].} =
  var xArr: array[bits div 8, byte] = x.toByteArrayBE()
  for b in 0 ..< 16:
    if (result.len == 0) and (xArr[b] == 0):
      continue
    result &= xArr[b].toHex()

#Converts a number to a binary string.
func toBinary*(
  number: SomeNumber,
  length: int = 0
): string {.forceCheck: [].} =
  var used: int = 0
  if number != 0:
    used = sizeof(number) - (countLeadingZeroBits(number) div 8)
  result = newString(max(length, used))

  var c: int = 0
  while c < used:
    result[c] = char((number shr (c * 8)) and 0b11111111)
    inc(c)

#Convert a char/string to a number.
func fromBinary*(
  number: char
): int {.inline, forceCheck: [].} =
  int(number)

func fromBinary*(
  number: string
): int {.forceCheck: [].} =
  #Disable checks so this can be used with unsigned numbers (with a binary casted result).
  {.push checks: off.}
  var counter: int = 0
  for c in number:
    result += int(c) shl counter
    counter += 8
  {.pop.}

#Extract a set of bits.
func extractBits*(
  data: uint16,
  start: int,
  bits: int
): uint16 {.forceCheck: [].} =
  (data shl start) shr (16 - bits)

func extractBits*(
  data: uint32,
  start: int,
  bits: int
): uint32 {.forceCheck: [].} =
  (data shl start) shr (32 - bits)

#Securely generates X random bytes,
proc randomFill*[T](
  arr: var openArray[T]
) {.forceCheck: [].} =
  try:
    if randomBytes(arr) != arr.len:
      raise newException(Exception, "")
  except Exception:
    #Can't panic due to only importing ErrorObjs.
    doAssert(false, "Couldn't randomly fill the passed array.")
