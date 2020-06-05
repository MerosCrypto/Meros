import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/DataDifficultyObj

import ../SerializeCommon

proc parseDataDifficulty*(
  dataDiffStr: string
): DataDifficulty {.forceCheck: [].} =
  #Holder's Nickname | Nonce | Difficulty
  var dataDiffSeq: seq[string] = dataDiffStr.deserialize(
    NICKNAME_LEN,
    INT_LEN,
    INT_LEN
  )

  #Create the DataDifficulty.
  result = newDataDifficultyObj(
    dataDiffSeq[1].fromBinary(),
    uint32(dataDiffSeq[2].fromBinary())
  )
  result.holder = uint16(dataDiffSeq[0].fromBinary())

proc parseSignedDataDifficulty*(
  dataDiffStr: string
): SignedDataDifficulty {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Nonce | Difficulty | BLS Signature
  var dataDiffSeq: seq[string] = dataDiffStr.deserialize(
    NICKNAME_LEN,
    INT_LEN,
    INT_LEN,
    BLS_SIGNATURE_LEN
  )

  #Create the DataDifficulty.
  try:
    result = newSignedDataDifficultyObj(
      dataDiffSeq[1].fromBinary(),
      uint32(dataDiffSeq[2].fromBinary())
    )
    result.holder = uint16(dataDiffSeq[0].fromBinary())
    result.signature = newBLSSignature(dataDiffSeq[3])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid signature.")
