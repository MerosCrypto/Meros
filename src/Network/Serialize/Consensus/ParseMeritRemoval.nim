import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/MeritRemoval

import ../SerializeCommon

import ParseElement, ParseVerification, ParseVerificationPacket
import ParseSendDifficulty, ParseDataDifficulty

#Parse an Element out of a MeritRemoval.
proc parseMeritRemovalElement(
  data: string,
  i: int,
  holder: string = ""
): tuple[
  element: Element,
  len: int
] {.forceCheck: [
  ValueError
].} =
  try:
    result.len = 0
    if int(data[i]) == VERIFICATION_PACKET_PREFIX:
      result.len = {
        byte(VERIFICATION_PACKET_PREFIX)
      }.getLength(data[i])

    result.len += MERIT_REMOVAL_ELEMENT_SET.getLength(
      data[i],
      data[i + 1 .. i + result.len].fromBinary(),
      MERIT_REMOVAL_PREFIX
    )
  except ValueError as e:
    raise e

  if i + result.len > data.len:
    raise newLoggedException(ValueError, "parseMeritRemovalElement not handed enough data to parse the next Element.")

  try:
    case int(data[i]):
      of VERIFICATION_PREFIX:
        result.element = parseVerification(holder & data[i + 1 ..< i + result.len])
      of VERIFICATION_PACKET_PREFIX:
        result.element = parseMeritRemovalVerificationPacket(data[i + 1 ..< i + result.len])
      of SEND_DIFFICULTY_PREFIX:
        result.element = parseSendDifficulty(holder & data[i + 1 ..< i + result.len])
      of DATA_DIFFICULTY_PREFIX:
        result.element = parseDataDifficulty(holder & data[i + 1 ..< i + result.len])
      else:
        panic("Possible Element wasn't supported.")
  except ValueError as e:
    raise e

#Parse a MeritRemoval.
proc parseMeritRemoval*(
  mrStr: string
): MeritRemoval {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
  var
    mrSeq: seq[string] = mrStr.deserialize(
      NICKNAME_LEN,
      BYTE_LEN
    )
    partial: bool

    pmreResult: tuple[
      element: Element,
      len: int
    ]
    i: int = NICKNAME_LEN + BYTE_LEN

    element1: Element
    element2: Element

  if mrSeq[1].len != 1:
    raise newLoggedException(ValueError, "MeritRemoval not handed enough data to get if it's partial.")
  case int(mrSeq[1][0]):
    of 0:
      partial = false
    of 1:
      partial = true
    else:
      raise newLoggedException(ValueError, "MeritRemoval has an invalid partial field.")

  try:
    pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
    i += pmreResult.len
    element1 = pmreResult.element
  except ValueError as e:
    raise e

  try:
    pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
    element2 = pmreResult.element
  except ValueError as e:
    raise e

  #Create the MeritRemoval.
  result = newMeritRemoval(
    uint16(mrSeq[0].fromBinary()),
    partial,
    element1,
    element2,
    @[]
  )

#Parse a Signed MeritRemoval.
proc parseSignedMeritRemoval*(
  mrStr: string
): SignedMeritRemoval {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
  var
    mrSeq: seq[string] = mrStr.deserialize(
      NICKNAME_LEN,
      BYTE_LEN
    )
    partial: bool

    i: int = NICKNAME_LEN + BYTE_LEN
    pmreResult: tuple[
      element: Element,
      len: int
    ]

    element1: Element
    element2: Element

  if mrSeq[1].len != 1:
    raise newLoggedException(ValueError, "MeritRemoval not handed enough data to get if it's partial.")
  case int(mrSeq[1][0]):
    of 0:
      partial = false
    of 1:
      partial = true
    else:
      raise newLoggedException(ValueError, "MeritRemoval has an invalid partial field.")

  try:
    pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
    i += pmreResult.len
    element1 = pmreResult.element
  except ValueError as e:
    raise e

  try:
    pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
    element2 = pmreResult.element
  except ValueError as e:
    raise e

  #Create the SignedMeritRemoval.
  try:
    result = newSignedMeritRemoval(
      uint16(mrSeq[0].fromBinary()),
      partial,
      element1,
      element2,
      newBLSSignature(mrStr[mrStr.len - BLS_SIGNATURE_LEN ..< mrStr.len]),
      @[]
    )
  except BLSError:
    raise newLoggedException(ValueError, "Invalid Signature.")
