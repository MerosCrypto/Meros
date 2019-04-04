#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

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
            score* {.final.}: uint #This is final even though we double set score (once with a raw value, once with a normalized value). How?
                                   #We initially set the score in this value via the constructor.
                                   #Since we set the score in this file, we don't call the finals setter, and finals thinks it's unset.
        #Seq of Rewards.
        Rewards* = seq[Reward]

        #Epoch object. Entry Hash -> Public Keys
        Epoch* = TableRef[string, seq[BLSPublicKey]]
        #Epochs object.
        Epochs* = ref object of RootObj
            #Database.
            db: DatabaseFunctionBox
            #Seq of the current 5 Epochs.
            epochs: seq[Epoch]
            #The last 12 Epochs of indexes.
            indexes: seq[seq[VerifierIndex]]

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
    newTable[string, seq[BLSPublicKey]]()

proc newEpochsObj*(db: DatabaseFunctionBox): Epochs {.raises: [].} =
    #Create the seq.
    result = Epochs(
        db: db,
        epochs: newSeq[Epoch](5),
        indexes: newSeq[seq[VerifierIndex]](10)
    )

    #Place blank epochs in.
    for i in 0 ..< 5:
        result.epochs[i] = newEpoch(@[])

    #Place blank indexes in.
    for i in 0 ..< 10:
        result.indexes[i] = @[]

#Add a hash to Epochs. Returns false if this hash isn't already in these Epochs.
proc add*(epochs: Epochs, hash: string, verifier: BLSPublicKey): bool {.raises: [KeyError].} =
    #Default return value of false.
    result = false

    #Check every Epoch.
    for epoch in epochs.epochs:
        #If we found the hash, add the verifier and return true.
        if epoch.hasKey(hash):
            epoch[hash].add(verifier)
            return true

#Add a hash to an Epoch.
proc add*(epoch: Epoch, hash: string, verifier: BLSPublicKey) {.raises: [KeyError].} =
    #Create the seq if one doesn't already exist.
    if not epoch.hasKey(hash):
        epoch[hash] = @[]

    #Add the key.
    epoch[hash].add(verifier)

#Shift an Epoch.
proc shift*(epochs: Epochs, epoch: Epoch, indexes: seq[VerifierIndex], save: bool): Epoch {.raises: [LMDBError].} =
    #Add the newest Epoch.
    epochs.epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

    #Add the newest indexes.
    epochs.indexes.add(indexes)
    #Grab the oldest.
    var oldIndexes: seq[VerifierIndex] = epochs.indexes[0]
    #Remove the oldest.
    epochs.indexes.delete(0)

    #If we should save this to the database...
    if save:
        discard """
        When we regenerate the Epochs, we can't just shift the last 5 blocks, for two reasons.

        1) When it adds the Verifications, it'd try loading everything from the archived to the specified index.
        When we boot up, the archived is the very last archived, not the archived it was when we originally shifted the Block.

        2) When it adds the Verifications, it'd assume every appearance is the first appearance.
        This is because it doesn't have the 5 Epochs before it so when it checks the Epochs, it's iterating over blanks.

        Therefore, we need to save the index that's at least 11 blocks old to merit_HOLDER_epoch (and then load the last 10 blocks).
        """

        for index in oldIndexes:
            epochs.db.put("merit_" & index.key & "_epoch", index.nonce.toBinary())
