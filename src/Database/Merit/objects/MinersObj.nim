#Finals lib.
import finals

#BLS lib.
import BLS

finalsd:
    type
        #Miner object.
        Miner* = object of RootObj
            miner* {.final.}: PublicKey
            amount* {.final.}: uint
        
        #Miners object.
        Miners* = seq[Miner]

func newMinerObj*(
    miner: PublicKey,
    amount: uint
): Miner {.raises: [].} =
    Miner(
        miner: miner,
        amount: amount
    )
