import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/SendDifficultyObj

import ../SerializeCommon

proc parseSendDifficulty*(
  sendDiffStr: string
): SendDifficulty {.forceCheck: [].} =
  #Holder's Nickname | Nonce | Difficulty
  var sendDiffSeq: seq[string] = sendDiffStr.deserialize(
    NICKNAME_LEN,
    INT_LEN,
    DIFFICULTY_LEN
  )

  #Create the SendDifficulty.
  result = newSendDifficultyObj(
    sendDiffSeq[1].fromBinary(),
    uint16(sendDiffSeq[2].fromBinary())
  )
  result.holder = uint16(sendDiffSeq[0].fromBinary())

proc parseSignedSendDifficulty*(
  sendDiffStr: string
): SignedSendDifficulty {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Nonce | Difficulty | BLS Signature
  var sendDiffSeq: seq[string] = sendDiffStr.deserialize(
    NICKNAME_LEN,
    INT_LEN,
    DIFFICULTY_LEN,
    BLS_SIGNATURE_LEN
  )

  #Create the SendDifficulty.
  try:
    result = newSignedSendDifficultyObj(
      sendDiffSeq[1].fromBinary(),
      uint16(sendDiffSeq[2].fromBinary())
    )
    result.holder = uint16(sendDiffSeq[0].fromBinary())
    result.signature = newBLSSignature(sendDiffSeq[3])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid signature.")
