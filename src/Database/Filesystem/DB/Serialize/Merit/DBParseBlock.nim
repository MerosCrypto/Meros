import ../../../../../lib/[Errors, Util, Hash]
import ../../../../../Wallet/MinerWallet

import ../../../../Consensus/Elements/Elements

import ../../../../Merit/Block

import ../../../../../Network/Serialize/SerializeCommon
import ../../../../../Network/Serialize/Merit/ParseBlockHeader
import ../../../../../Network/Serialize/Consensus/ParseBlockElement

proc parseBlock*(
  blockStr: string,
  interimHash: string,
  hash: Hash[256]
): Block {.forceCheck: [
  ValueError
].} =
  #Header | Body
  var
    header: BlockHeader
    bodyStr: string

  #Parse the header.
  try:
    header = blockStr.parseBlockHeader(interimHash, hash)
  except ValueError as e:
    raise e

  #Grab the body.
  bodyStr = blockStr.substr(
    BLOCK_HEADER_DATA_LEN +
    (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN) +
    INT_LEN + INT_LEN + BLS_SIGNATURE_LEN
  )

  #Packets Contents | Packets Length | Packets | Amount of Elements | Elements | Aggregate Signature | Removals
  var
    packetsContents: Hash[256]
    packetsLen: int = bodyStr[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary()
    packetsStart: int = HASH_LEN + INT_LEN

    packets: seq[VerificationPacket] = newSeq[VerificationPacket](packetsLen)
    i: int

    elementsLen: int
    pbeResult: tuple[
      element: BlockElement,
      len: int
    ]
    elements: seq[BlockElement] = @[]

    aggregate: BLSSignature

    removals: set[uint16] = {}

  packetsContents = bodyStr[0 ..< HASH_LEN].toHash[:256]()

  i = packetsStart
  if bodyStr.len < i + NICKNAME_LEN:
    raise newLoggedException(ValueError, "DB parseBlock not handed enough data to get the amount of holders in the next VerificationPacket.")

  var holders: seq[uint16]
  for p in 0 ..< packetsLen:
    holders = newSeq[uint16](bodyStr[i ..< i + NICKNAME_LEN].fromBinary())
    i += NICKNAME_LEN

    #The holders is represented by a NICKNAME_LEN. This uses an INT_LEN so the last packet checks the elements length.
    if bodyStr.len < i + (holders.len * NICKNAME_LEN) + HASH_LEN + INT_LEN:
      raise newLoggedException(ValueError, "DB parseBlock not handed enough data to get the holders in this VerificationPacket, its hash, and the amount of holders in the next VerificationPacket.")

    for h in 0 ..< holders.len:
      holders[h] = uint16(bodyStr[i ..< i + NICKNAME_LEN].fromBinary())
      i += NICKNAME_LEN

    packets[p] = newVerificationPacketObj(bodyStr[i ..< i + HASH_LEN].toHash[:256]())
    i += HASH_LEN
    packets[p].holders = holders

  elementsLen = bodyStr[i ..< i + INT_LEN].fromBinary()
  i += INT_LEN
  for e in 0 ..< elementsLen:
    try:
      pbeResult = bodyStr.parseBlockElement(i)
    except ValueError as e:
      raise e
    i += pbeResult.len
    elements.add(pbeResult.element)

  if bodyStr.len < i + BLS_SIGNATURE_LEN:
    raise newLoggedException(ValueError, "DB parseBlock not handed enough data to get the aggregate signature.")

  try:
    aggregate = newBLSSignature(bodyStr[i ..< i + BLS_SIGNATURE_LEN])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid aggregate signature.")
  i += BLS_SIGNATURE_LEN

  for h in countup(i, bodyStr.len - 1, 2):
    removals.incl(uint16(bodyStr[h ..< h + 2].fromBinary()))

  result = newBlockObj(
    header,
    newBlockBodyObj(
      packetsContents,
      packets,
      elements,
      aggregate,
      removals
    )
  )
