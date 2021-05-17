import ../../../lib/[Errors, Hash]

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
  if dataStr.len != (
    HASH_LEN +
    BYTE_LEN +
    (int(dataStr[HASH_LEN]) + 1) +
    RISTRETTO_SIGNAURE_LEN +
    INT_LEN
  ):
    raise newLoggedException(ValueError, "parseData handed the wrong amount of data.")

  #Input | Data Length | Data | Signature | Proof
  var dataSeq: seq[string] = dataStr.deserialize(
    HASH_LEN,
    BYTE_LEN,
    int(dataStr[HASH_LEN]) + 1,
    RISTRETTO_SIGNAURE_LEN,
    INT_LEN
  )

  result = newDataObj(dataSeq[0].toHash[:256](), dataSeq[2])
  result.hash = Blake256("\3" & dataSeq[0] & dataSeq[2])
  result.signature = cast[seq[byte]](dataSeq[3])
  result.proof = uint32(dataSeq[4].fromBinary())

  #Verify the Data isn't spam.
  if result.overflows(diff):
    raise newSpam("Data didn't beat the difficulty.", result.hash, result.getDifficultyFactor() * diff)
