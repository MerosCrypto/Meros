import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import objects/SendDifficultyObj
export SendDifficultyObj

import ../../../Network/Serialize/Consensus/SerializeSendDifficulty

proc sign*(
  miner: MinerWallet,
  sendDiff: SignedSendDifficulty
) {.forceCheck: [].} =
  sendDiff.holder = miner.nick
  sendDiff.signature = miner.sign(sendDiff.serializeWithoutHolder())
