#BLS lib.
import ../../../lib/BLS

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#VerifierIndex object.
import VerifierIndexObj

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

        #Epoch object.
        Epoch* = ref object of RootObj
            #Entry Hash -> Public Keys
            verifications*: TableRef[string, seq[BLSPublicKey]]
            #List of Verifiers and what tip was used for this Epoch.
            indexes*: seq[VerifierIndex]
        #Seq of epochs.
        Epochs* = ref object of RootObj
            db*: DatabaseFunctionBox
            epochs*: seq[Epoch]

#Constructors.
proc newReward*(key: string, score: uint): Reward {.raises: [].} =
    result = Reward(
        key: key,
        score: score
    )
    result.ffinalizeKey()

proc newRewards*(): Rewards {.raises: [].} =
    newSeq[Reward]()

proc newEpoch*(indexes: seq[VerifierIndex]): Epoch {.raises: [].} =
    Epoch(
        verifications: newTable[string, seq[BLSPublicKey]](),
        indexes: indexes
    )

proc newEpochs*(db: DatabaseFunctionBox): Epochs {.raises: [].} =
    #Create the seq.
    result = Epochs(
        db: db,
        epochs: newSeq[Epoch](6)
    )

    #Place blank epochs in.
    for i in 0 ..< 6:
        result.epochs[i] = newEpoch(@[])
