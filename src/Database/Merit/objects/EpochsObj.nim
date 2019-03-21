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

        #Epoch object.
        Epoch* = ref object of RootObj
            #Entry Hash -> Public Keys
            verifications*: TableRef[string, seq[BLSPublicKey]]
            #List of Verifiers and what tip was used for this Epoch.
            indexes: seq[VerifierIndex]
        #Seq of epochs.
        Epochs* = ref object of RootObj
            db: DatabaseFunctionBox
            epochs: seq[Epoch]

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

#Add a hash to Epochs. Returns false if this hash isn't already in these Epochs.
proc add*(epochs: Epochs, hash: string, verifier: BLSPublicKey): bool {.raises: [KeyError].} =
    #Default return value of false.
    result = false

    #Check every Epoch.
    for epoch in epochs.epochs:
        #If we found the hash, add the verifier and return true.
        if epoch.verifications.hasKey(hash):
            epoch.verifications[hash].add(verifier)
            return true

#Add a hash to an Epoch.
proc add*(epoch: Epoch, hash: string, verifier: BLSPublicKey) {.raises: [KeyError].} =
    #Create the seq if one doesn't already exist.
    if not epoch.verifications.hasKey(hash):
        epoch.verifications[hash] = @[]

    #Add the key.
    epoch.verifications[hash].add(verifier)

#Shift an Epoch.
proc shift*(epochs: Epochs, epoch: Epoch, save: bool = true): Epoch {.raises: [LMDBError].} =
    #Add the newest Epoch.
    epochs.epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

    #If we should save this to the database...
    if save:
        #When we regenerate the Epochs, we can't just shift the last 6 blocks.
        #When it adds the Verifications, it'd try loading everything from the archived to the specified tip.
        #When we boot up, the archived is the very last archived, not the archived it was when we originally shifted the Block.
        #Therefore, we save the tip of every Verifier, as it was before the 6 blocks in the current Epochs.

        #We also need to know which Entries were mentioned in the Epochs before the Epochs we regenerate.
        #This is so we don't assign Entries to current Epochs when they were assigned to previous Epoch.
        #Therefore, we need to set the current merit_holder_epoch to merit_previous_epoch, if one exists.
        #This must be done first as else we'd overwrite it.
        for index in result.indexes:
            try:
                epochs.db.put("merit_" & index.key & "_previous_epoch", epochs.db.get("merit_" & index.key & "_epoch"))
            except:
                #They didn't already have a merit_holder_epoch.
                discard

            #Now, save the tip.
            epochs.db.put("merit_" & index.key & "_epoch", index.nonce.toBinary())
