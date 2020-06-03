import bitops
import times

import strutils
export toHex, parseHexStr, parseHexInt, parseUInt

import nimcrypto

#Manually import these to stop a recursive dependency.
import ForceCheck
import objects/ErrorObjs

#Gets the epoch and returns it.
proc getTime*(): uint32 {.inline, forceCheck: [].} =
  uint32(times.getTime().toUnix())

#Left-pads data, with a char or string, until the data is a certain length.
func pad*(
  data: string,
  len: int,
  prefix: char or string = char(0)
): string {.forceCheck: [].} =
  result = $data

  while result.len < len:
    result = prefix & result

#Reverse a string.
func reverse*(
  data: string
) : string {.forceCheck: [].} =
  result = newString(data.len)
  for i in 0 ..< data.len:
    result[data.len - 1 - i] = data[i]

#Converts a number to a binary string.
func toBinary*(
  number: SomeNumber,
  length: int = 0
): string {.forceCheck: [].} =
  #Get the amount of bytes the number actually uses.
  var used: int = 0
  if number != 0:
    used = sizeof(number) - (countLeadingZeroBits(number) div 8)

  #Add filler bytes to the final result is at least length.
  #If the amount of bytes needed is more than the length, the result will be the amount needed.
  result = newString(max(length - used, 0))

  #Shift counters.
  var
    mask: uint = 255
    fromEnd: int = (used - 1) * 8

  #Iterate over each byte.
  while fromEnd >= 0:
    result &= char((uint64(number) and uint64(mask shl fromEnd)) shr fromEnd)
    fromEnd -= 8

#Convert a char/string to a number.
func fromBinary*(
  number: char
): int {.inline, forceCheck: [].} =
  int(number)

func fromBinary*(
  number: string
): int {.forceCheck: [].} =
  #Iterate over each byte.
  for b in 0 ..< number.len:
    #Add the byte after it's been properly shifted.
    result += int(number[b]) shl ((number.len - b - 1) * 8)

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
) {.forceCheck: [
  RandomError
].} =
  try:
    if randomBytes(arr) != arr.len:
      raise newException(Exception, "")
  except Exception:
    raise newException(RandomError, "Couldn't randomly fill the passed array.")
