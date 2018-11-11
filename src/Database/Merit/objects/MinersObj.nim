#BLS lib.
import ../../../lib/BLS

#Finals lib.
import finals

finalsd:
    type
        #Miner object.
        Miner* = object of RootObj
            miner* {.final.}: BLSPublicKey
            amount* {.final.}: uint

        #Miners object.
        Miners* = seq[Miner]

func newMinerObj*(
    miner: BLSPublicKey,
    amount: uint
): Miner {.raises: [].} =
    result = Miner(
        miner: miner,
        amount: amount
    )
    result.ffinalizeMiner()
    result.ffinalizeAmount()
