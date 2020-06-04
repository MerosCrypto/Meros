import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import objects/DataDifficultyObj
export DataDifficultyObj

import ../../../Network/Serialize/Consensus/SerializeDataDifficulty

proc sign*(
  miner: MinerWallet,
  dataDiff: SignedDataDifficulty
) {.forceCheck: [].} =
  dataDiff.holder = miner.nick
  dataDiff.signature = miner.sign(dataDiff.serializeWithoutHolder())
