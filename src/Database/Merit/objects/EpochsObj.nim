#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib (for BLSPublicKey).
import ../../../Wallet/MinerWallet

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Tables standard lib.
import tables

#Finals lib.
import finals

finalsd:
    type
        #Reward object. Declares a BLS Public Key and a number which adds up to 1000.
        Reward* = object
            key* {.final.}: BLSPublicKey
            score*: uint64

        #Epoch object. Transaction Hash -> BLS Public Keys of verifiers.
        Epoch* = object
            hashes*: Table[Hash[384], seq[BLSPublicKey]]

        #Epochs object.
        Epochs* = object
            #Database.
            db: DB
            #Seq of the current 5 Epochs.
            epochs: seq[Epoch]

#Constructors.
func newReward*(
    key: BLSPublicKey,
    score: uint64
): Reward {.forceCheck: [].} =
    result = Reward(
        key: key,
        score: score
    )
    result.ffinalizeKey()

func newEpoch*(): Epoch {.inline, forceCheck: [].} =
    Epoch(
        hashes: initTable[Hash[384], seq[BLSPublicKey]]()
    )

func newEpochsObj*(
    db: DB
): Epochs {.forceCheck: [].} =
    #Create the seq.
    result = Epochs(
        db: db,
        epochs: newSeq[Epoch](5)
    )

    #Place blank epochs in.
    for i in 0 ..< 5:
        result.epochs[i] = newEpoch()

#Adds a hash to Epochs. Throws NotInEpochs error if the hash isn't in the Epochs.
func add*(
    epochs: var Epochs,
    hash: Hash[384],
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
    hash: Hash[384],
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
    epoch: Epoch
): Epoch {.forceCheck: [].} =
    #Add the newest Epoch.
    epochs.epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

#Get the latest Epoch.
func latest*(
    epochs: Epochs
): Epoch {.forceCheck: [].} =
    epochs.epochs[4]
