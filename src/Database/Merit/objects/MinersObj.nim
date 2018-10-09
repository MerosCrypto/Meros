#Finals lib.
import finals

finalsd:
    type
        #Miner object.
        Miner* = object of RootObj
            miner* {.final.}: string
            amount* {.final.}: uint
        #Miners object.
        Miners* = seq[Miner]

func newMinerObj*(
    miner: string,
    amount: uint
): Miner {.raises: [].} =
    Miner(
        miner: miner,
        amount: amount
    )
