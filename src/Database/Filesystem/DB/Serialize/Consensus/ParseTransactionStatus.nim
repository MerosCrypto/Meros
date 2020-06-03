import sets
import tables

import ../../../../../lib/[Errors, Util, Hash]
import ../../../../../Wallet/MinerWallet

import ../../../../Consensus/Elements/objects/VerificationPacketObj
import ../../../../Consensus/objects/TransactionStatusObj

import ../../../../../Network/Serialize/SerializeCommon

const HOLDERS_START: int = INT_LEN + BYTE_LEN + BYTE_LEN + BYTE_LEN + BYTE_LEN + NICKNAME_LEN

proc parseTransactionStatus*(
  statusStr: string,
  hash: Hash[256]
): TransactionStatus {.forceCheck: [].} =
  var
    #[
    Epoch | Finalized | Competing | Verified | Beaten |
    Holders Len | (Holder Nick + Signature availability + Signature if available)s |
    Pending Len if not finalized | Pending Nicks if not finalized |
    Merit (if finalized)
    ]#
    statusSeq: seq[string] = statusStr.deserialize(
      INT_LEN,
      BYTE_LEN,
      BYTE_LEN,
      BYTE_LEN,
      BYTE_LEN,
      NICKNAME_LEN
    )
    finalized: bool = bool(statusSeq[1][0])
    holdersCursor: int = HOLDERS_START

  #Create the TransactionStatus.
  result = newTransactionStatusObj(
    hash,
    statusSeq[0].fromBinary()
  )

  result.competing = bool(statusSeq[2][0])
  result.verified = bool(statusSeq[3][0])
  result.beaten = bool(statusSeq[4][0])

  result.holders = initHashSet[uint16]()
  for h in 0 ..< statusSeq[5].fromBinary():
    var holder: uint16 = uint16(statusStr[holdersCursor ..< holdersCursor + NICKNAME_LEN].fromBinary())
    result.holders.incl(holder)
    holdersCursor += NICKNAME_LEN

    if bool(statusStr[holdersCursor]):
      inc(holdersCursor)
      try:
        result.signatures[holder] = newBLSSignature(statusStr[holdersCursor ..< holdersCursor + BLS_SIGNATURE_LEN])
      except BLSError as e:
        panic("Couldn't parse a BLS Signature loaded from the Database as part of a TransactionStatus: " & e.msg)
      holdersCursor += BLS_SIGNATURE_LEN
    else:
      inc(holdersCursor)

  if finalized:
    result.packet = newSignedVerificationPacketObj(hash)
    result.merit = statusStr[holdersCursor ..< holdersCursor + NICKNAME_LEN].fromBinary()
  else:
    result.pending = initHashSet[uint16]()
    result.packet = newSignedVerificationPacketObj(hash)
    result.packet.holders = newSeq[uint16](statusStr[holdersCursor ..< holdersCursor + NICKNAME_LEN].fromBinary())
    for h in 0 ..< result.packet.holders.len:
      result.packet.holders[h] = uint16(
        statusStr[holdersCursor + ((h + 1) * NICKNAME_LEN) ..< holdersCursor + ((h + 2) * NICKNAME_LEN)].fromBinary()
      )
      result.pending.incl(result.packet.holders[h])

    var pendingSigs: seq[BLSSignature] = @[]
    for holder in result.packet.holders:
      try:
        pendingSigs.add(result.signatures[holder])
      except KeyError as e:
        panic("Pending holder didn't have a signature in an unfinalized TransactionStatus: " & e.msg)
    result.packet.signature = pendingSigs.aggregate()
