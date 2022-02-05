import sequtils, strutils

import ../lib/Errors

#Human readable data.
const ADDRESS_HRP {.strdefine.}: string = "mr"

#Expands the HRP.
func expandHRP(): seq[byte] {.compileTime.} =
  result = @[]
  for c in ADDRESS_HRP:
    result.add(byte(int(c) shr 5))
  result.add(0)
  for c in ADDRESS_HRP:
    result.add(byte(int(c) and 31))

#Expanded HRP.
const HRP: seq[byte] = expandHRP()

#Base32 characters.
const CHARACTERS: string = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

#Hex constants used for the BCH code.
const BCH_VALUES: array[5, uint32] = [
  uint32(0x3B6A57B2),
  uint32(0x26508E6D),
  uint32(0x1EA119FA),
  uint32(0x3D4233DD),
  uint32(0x2A1462B3)
]

#Constant to verify the BCH against.
const BECH32M_CONST: uint32 = uint32(0x2BC830A3)

type
  #AddressType enum.
  #Right now, there's only PublicKey, yet in the future, there may PublicKeyHash/Stealth.
  #Cannot have gaps due to the below address verification code.
  AddressType* = enum
    None = 0 #Present so BTC Bech32 libraries can be used, as the Python reference uses Bech32 for 0.
             #Any value other than 0 uses Bech32m, which is what we use.
    PublicKey = 1

  #Address object. Specifically stores a decoded address.
  Address* = object
    addyType*: AddressType
    data*: seq[byte]

#BCH Polymod function.
func polymod(
  values: seq[byte]
): uint32 {.forceCheck: [].} =
  result = 1
  var b: uint32
  for value in values:
    b = result shr 25
    result = ((result and 0x01FFFFFF) shl 5) xor value
    for i in 0 ..< 5:
      if ((b shr i) and 1) == 1:
        result = result xor BCH_VALUES[i]

#Generates a BCH code.
func generateBCH(
  data: seq[byte]
): seq[byte] {.forceCheck: [].} =
  let polymod: uint32 = polymod(
    HRP
    .concat(data)
    .concat(@[
      byte(0),
      byte(0),
      byte(0),
      byte(0),
      byte(0),
      byte(0)
    ])
  ) xor BECH32M_CONST

  result = @[]
  for i in 0 ..< 6:
    result.add(
      byte((polymod shr (5 * (5 - i))) and 31)
    )

#Verifies a BCH code via a data argument of the Public Key and BCH code.
func verifyBCH(
  data: seq[byte]
): bool {.inline, forceCheck: [].} =
  polymod(HRP.concat(data)) == BECH32M_CONST

#Convert between two bases.
proc convert(
  data: seq[byte],
  fromBits: int,
  to: int,
  encoding: bool
): seq[byte] {.forceCheck: [
  ValueError
].} =
  var
    acc: int = 0
    bits: int = 0
  let
    maxv: int = (1 shl to) - 1
    max_acc: int = (1 shl (fromBits + to - 1)) - 1

  for value in data:
    acc = ((acc shl fromBits) or int(value)) and max_acc
    bits += fromBits
    while bits >= to:
      bits -= to
      result.add(byte((acc shr bits) and maxv))

  #Handle padding.
  if encoding:
    if bits > 0:
      result.add(byte((acc shl (to - bits)) and maxv))
  elif (bits >= fromBits) or (((acc shl (to - bits)) and maxv) != 0):
    raise newLoggedException(ValueError, "Invalid address padding.")

#Create a new address.
proc newAddress*(
  addyType: AddressType,
  dataArg: string
): string {.forceCheck: [].} =
  result = ADDRESS_HRP & "1"
  var data: seq[byte]
  try:
    data = byte(addyType) & convert(cast[seq[byte]](dataArg), 8, 5, true)
  except ValueError:
    panic("Padding check was run, and failed, when encoding a Bech32 string.")

  for c in data:
    result &= CHARACTERS[c]
  for c in generateBCH(data):
    result &= CHARACTERS[c]

#Checks if an address is valid.
proc isValidAddress*(
  address: string
): bool {.forceCheck: [].} =
  if (
    #Check the prefix.
    (address.substr(0, ADDRESS_HRP.len).toLower() != ADDRESS_HRP & "1") or
    #Check the length.
    (address.len < ADDRESS_HRP.len + 6) or
    #Make sure it's all upper case or all lower case.
    (address.toLower() != address) and (address.toUpper() != address)
  ):
    return false

  #Check to make sure it's a valid Base32 number.
  for c in address.substr(ADDRESS_HRP.len + 1, address.len).toLower():
    if CHARACTERS.find(c) == -1:
      return false

  #Check the BCH code.
  var
    dataStr: string = address.substr(ADDRESS_HRP.len + 1, address.len).toLower()
    data: seq[byte] = @[]
  if dataStr.len == 6:
    return false
  for c in dataStr:
    data.add(byte(CHARACTERS.find(c)))

  try:
    discard convert(data[1 ..< data.len - 6], 5, 8, false)
  except ValueError:
    return false

  return verifyBCH(data)

#Get the data encoded in an address.
proc getEncodedData*(
  address: string
): Address {.forceCheck: [
  ValueError
].} =
  if not address.isValidAddress():
    raise newLoggedException(ValueError, "Invalid address.")

  var
    data: string = address.substr(ADDRESS_HRP.len + 1, address.len).toLower()
    converted: seq[byte]
  for c in 0 ..< data.len - 6:
    converted.add(byte(CHARACTERS.find(data[c])))

  try:
    converted = converted[0] & convert(converted[1 ..< converted.len], 5, 8, false)
  except ValueError as e:
    panic("Couldn't convert the bits of a valid address: " & e.msg)

  if converted[0] > byte(high(AddressType)):
    raise newLoggedException(ValueError, "Invalid address type.")
  case AddressType(converted[0]):
    of AddressType.None:
      raise newLoggedException(ValueError, "Address type None.")
    of AddressType.PublicKey:
      if converted.len != 33:
        raise newLoggedException(ValueError, "Invalid Public Key.")

  result = Address(
    addyType: AddressType(converted[0]),
    data: converted[1 ..< converted.len]
  )
