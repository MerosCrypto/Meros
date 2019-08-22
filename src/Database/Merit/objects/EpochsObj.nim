#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib (for BLSPublicKey).
import ../../../Wallet/MinerWallet

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#MeritHolderRecord object.
import ../../common/objects/MeritHolderRecordObj

#Tables standard lib.
import tables

#Finals lib.
import finals

finalsd:
    type
        #Reward object. Declares a BLS Public Key (as a string) and a number which adds up to 1000.
        Reward* = object
            key* {.final.}: string
            score*: uint64

        #The tests rely on Epoch and Epochs not being refs.
        #Epoch object. Transaction Hash -> BLS Public Keys of verifiers.
        Epoch* = object
            hashes*: Table[string, seq[BLSPublicKey]]
            records*: seq[MeritHolderRecord]

        #Epochs object.
        Epochs* = object
            #Database.
            db: DB

            #Seq of the current 5 Epochs.
            epochs: seq[Epoch]
            #The last five MeritHolderRecords to have been shifted out of Epochs.
            records*: seq[seq[MeritHolderRecord]]

#Constructors.
func newReward*(
    key: string,
    score: uint64
): Reward {.forceCheck: [].} =
    result = Reward(
        key: key,
        score: score
    )
    result.ffinalizeKey()

func newEpoch*(
    records: seq[MeritHolderRecord]
): Epoch {.inline, forceCheck: [].} =
    Epoch(
        hashes: initTable[string, seq[BLSPublicKey]](),
        records: records
    )

func newEpochsObj*(
    db: DB
): Epochs {.forceCheck: [].} =
    #Create the seq.
    result = Epochs(
        db: db,
        epochs: newSeq[Epoch](5),
        records: newSeq[seq[MeritHolderRecord]](5)
    )

    #Place blank epochs in.
    for i in 0 ..< 5:
        result.epochs[i] = newEpoch(@[])

    #Place blank records in.
    for i in 0 ..< 5:
        result.records[i] = @[]

#Adds a hash to Epochs. Throws NotInEpochs error if the hash isn't in the Epochs.
func add*(
    epochs: var Epochs,
    hash: string,
    holder: BLSPublicKey
) {.forceCheck: [
    NotInEpochs
].} =
    #Check every Epoch.
    try:
        for i in 0 ..< epochs.epochs.len:
            #If we found the hash, add the holder and return true.
            if epochs.epochs[i].hashes.hasKey(hash):
                for key in epochs.epochs[i].hashes[hash]:
                    if key == holder:
                        return
                epochs.epochs[i].hashes[hash].add(holder)
                return
    except KeyError as e:
        doAssert(false, "Couldn't add a hash to an Epoch which already has said hash: " & e.msg)
    raise newException(NotInEpochs, "")

#Add a hash to an Epoch.
func add*(
    epoch: var Epoch,
    hash: string,
    holder: BLSPublicKey
) {.forceCheck: [].} =
    #Create the seq, if one doesn't already exist.
    if not epoch.hashes.hasKey(hash):
        epoch.hashes[hash] = @[]

    #Add the key.
    try:
        epoch.hashes[hash].add(holder)
    except KeyError as e:
        doAssert(false, "Couldn't add a hash to a newly created seq in the Epoch: " & e.msg)

#Shift an Epoch.
proc shift*(
    epochs: var Epochs,
    epoch: Epoch,
    save: bool
): Epoch {.forceCheck: [].} =
    #Add the newest Epoch.
    epochs.epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

    #Add the newly shifted records.
    epochs.records.add(result.records)
    #Grab the oldest.
    let records: seq[MeritHolderRecord] = epochs.records[0]
    #Remove the oldest.
    epochs.records.delete(0)

    #If we should save this to the database...
    if save:
        discard """
        When we regenerate the Epochs, we can't just shift the last 5 blocks, for two reasons.

        1) When it adds the Verifications, it'd try loading everything from the archived to the specified record.
        When we boot up, the archived is the very last archived, not the archived it was when we originally shifted the Block.

        2) When it adds the Verifications, it'd assume every appearance is the first appearance.
        This is because it doesn't have the 5 Epochs before it so when it checks the Epochs, it's iterating over blanks.

        Therefore, we need to save the nonce that's 11 blocks old to merit_HOLDER_epoch (and then load the last 10 blocks).
        """

        for record in records:
            epochs.db.saveHolderEpoch(record.key, record.nonce)
