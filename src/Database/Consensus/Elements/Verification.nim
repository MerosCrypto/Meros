import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import objects/VerificationObj
export VerificationObj

import ../../../Network/Serialize/Consensus/SerializeVerification

proc sign*(
  miner: MinerWallet,
  verif: SignedVerification
) {.forceCheck: [].} =
  verif.holder = miner.nick
  verif.signature = miner.sign(verif.serializeWithoutHolder())
