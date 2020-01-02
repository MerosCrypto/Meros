#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#SendDifficulty object.
import objects/SendDifficultyObj
export SendDifficultyObj

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeSendDifficulty

#Sign a SendDifficulty.
proc sign*(
    miner: MinerWallet,
    sendDiff: SignedSendDifficulty
) {.forceCheck: [].} =
    #Set the holder.
    sendDiff.holder = miner.nick
    #Sign the difficulty of the SendDifficulty.
    sendDiff.signature = miner.sign(sendDiff.serializeWithoutHolder())
