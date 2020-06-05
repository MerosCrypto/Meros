import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import ../../../Database/Transactions/objects/DataObj

import ../SerializeCommon

proc parseData*(
  dataStr: string,
  diff: uint32
): Data {.forceCheck: [
  ValueError,
  Spam
].} =
  #Verify the input length.
  if dataStr.len < HASH_LEN + BYTE_LEN:
    raise newLoggedException(ValueError, "parseData not handed enough data to get the length of the data.")

  if dataStr.len < HASH_LEN + BYTE_LEN + int(dataStr[HASH_LEN]) + BYTE_LEN:
    raise newLoggedException(ValueError, "parseData not handed enough data to get the data.")

  #Input | Data Length | Data | Signature | Proof
  var dataSeq: seq[string] = dataStr.deserialize(
    HASH_LEN,
    BYTE_LEN,
    int(dataStr[HASH_LEN]) + 1,
    ED_SIGNATURE_LEN,
    INT_LEN
  )

  result = newDataObj(dataSeq[0].toHash[:256](), dataSeq[2])

  #Verify the Data isn't spam.
  var
    hash: Hash[256] = Blake256("\3" & dataSeq[0] & dataSeq[2])
    argon: Hash[256] = Argon(hash.serialize(), dataSeq[4].pad(8))
    factor: uint32 = result.getDifficultyFactor()
  if argon.overflows(factor * diff):
    raise newSpam("Data didn't beat the difficulty.", hash, argon, factor * diff)

  result.hash = hash
  result.signature = newEdSignature(dataSeq[3])
  result.proof = uint32(dataSeq[4].fromBinary())
  result.argon = argon
