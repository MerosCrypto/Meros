#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DataDifficulty object.
import objects/DataDifficultyObj
export DataDifficultyObj

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeDataDifficulty

#Sign a DataDifficulty.
proc sign*(
  miner: MinerWallet,
  dataDiff: SignedDataDifficulty
) {.forceCheck: [].} =
  #Set the holder.
  dataDiff.holder = miner.nick
  #Sign the difficulty of the DataDifficulty.
  dataDiff.signature = miner.sign(dataDiff.serializeWithoutHolder())
