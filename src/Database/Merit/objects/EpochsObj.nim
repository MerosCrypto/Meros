#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib (for BLSPublicKey).
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#VerifierIndex object.
import ../../common/objects/VerifierIndexObj

#Tables standard lib.
import tables

#Finals lib.
import finals

finalsd:
    type
        #Reward object. Declares a BLS Public Key (as a string) and a number which adds up to 1000.
        Reward* = object
            key* {.final.}: string
            score* {.final.}: Natural #This is final even though we double set score (once with a raw value, once with a normalized value). How?
                                      #We initially set the score in this value via the constructor.
                                      #Since we set the score in this file, and we don't call the finalize, finals thinks it's unset.
        #Seq of Rewards.
        Rewards* = seq[Reward]

        #Epoch object. Entry Hash -> Public Keys
        Epoch* = Table[string, seq[BLSPublicKey]]

        #Epochs object.
        Epochs* = object
            #Database.
            db: DatabaseFunctionBox

            #Seq of the current 5 Epochs.
            epochs: seq[Epoch]
            #The last 10 Epochs of indexes.
            indexes: seq[seq[VerifierIndex]]

#Constructors.
func newReward*(
    key: string,
    score: Natural
): Reward {.forceCheck: [].} =
    result = Reward(
        key: key,
        score: score
    )
    result.ffinalizeKey()

func newRewards*(): Rewards {.inline, forceCheck: [].} =
    newSeq[Reward]()

func newEpoch*(
    indexes: seq[VerifierIndex]
): Epoch {.inline, forceCheck: [].} =
    initTable[string, seq[BLSPublicKey]]()

func newEpochsObj*(
    db: DatabaseFunctionBox
): Epochs {.forceCheck: [].} =
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

#Adds a hash to Epochs. Throws NotInEpochs error if the hash isn't in the Epochs.
func add*(
    epochs: var Epochs,
    hash: string,
    verifier: BLSPublicKey
) {.forceCheck: [
    NotInEpochsError
].} =
    #Check every Epoch.
    try:
        for i in 0 ..< epochs.epochs.len:
            #If we found the hash, add the verifier and return true.
            if epochs.epochs[i].hasKey(hash):
                epochs.epochs[i][hash].add(verifier)
                return
    except KeyError as e:
        doAssert(false, "Couldn't add a hash to an Epoch which already has said hash: " & e.msg)
    raise newException(NotInEpochsError, "")

#Add a hash to an Epoch.
func add*(
    epoch: var Epoch,
    hash: string,
    verifier: BLSPublicKey
) {.forceCheck: [].} =
    #Create the seq.
    try:
        epoch[hash] = @[]
    except KeyError as e:
        doAssert(false, "Couldn't add a seq to an Epoch: " & e.msg)

    #Add the key.
    try:
        epoch[hash].add(verifier)
    except KeyError as e:
        doAssert(false, "Couldn't add a hash to a newly created seq in the Epoch: " & e.msg)

#Shift an Epoch.
proc shift*(
    epochs: var Epochs,
    epoch: Epoch,
    indexes: seq[VerifierIndex],
    save: bool
): Epoch {.forceCheck: [].} =
    #Add the newest Epoch.
    epochs.epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

    #Add the newest indexes.
    epochs.indexes.add(indexes)
    #Grab the oldest.
    let oldIndexes: seq[VerifierIndex] = epochs.indexes[0]
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

        try:
            for index in oldIndexes:
                epochs.db.put("merit_" & index.key & "_epoch", index.nonce.toBinary())
        except DBWriteError as e:
            doAssert(false, "Couldn't save the new Epoch tip to the database: " & e.msg)
