#BLS lib.
import ../../../lib/BLS

#Tables standard lib.
import tables

#Finals lib.
import finals

finalsd:
    type
        #Reward object. Declares a BLS Public Key (as a string) and a number which adds up to 1000.
        Reward* = object of RootObj
            key* {.final.}: string
            score*: uint #This is not final since we double set score; once with a raw value, once with a normalized value.
        #Seq of Rewards.
        Rewards* = seq[Reward]

        #Epoch. Entry Hash -> Public Keys.
        Epoch* = TableRef[string, seq[BLSPublicKey]]
        #Seq of 6 epochs.
        Epochs* = seq[Epoch]

#Constructors.
proc newReward*(key: string, score: uint): Reward {.raises: [].} =
    result = Reward(
        key: key,
        score: score
    )
    result.ffinalizeKey()

proc newRewards*(): Rewards {.raises: [].} =
    newSeq[Reward]()

proc newEpoch*(): Epoch {.raises: [].} =
    newTable[string, seq[BLSPublicKey]]()

proc newEpochs*(): Epochs {.raises: [].} =
    #Create the seq.
    result = newSeq[Epoch](6)

    #Place blank epochs in.
    for i in 0 ..< 6:
        result[i] = newEpoch()
