#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib (for BLSPublicKey's toString).
import ../../Wallet/MinerWallet

#Consensus lib.
import ../Consensus/Consensus

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Block, Blockcain, and State lib.
import Block
import Blockchain
import State

#Epoch objects.
import objects/EpochsObj
export EpochsObj

#Sequtils standard lib (used to remove Rewards).
import sequtils

#Algorithm standard lib (used to sort Rewards).
import algorithm

#Tables standard lib.
import tables

#This shift does three things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
proc shift*(
    epochs: var Epochs,
    consensus: Consensus,
    removals: seq[MeritHolderRecord]
): Epoch {.forceCheck: [].} =
    var
        #New Epoch for any Verifications belonging to Transactions that aren't in an older Epoch.
        newEpoch: Epoch = newEpoch()
        #Loop variable of what Element to start with.
        start: int
        #Verifications we're handling.
        elements: seq[Element]

    #Loop over each record.
    for record in records:
        #If this person just lost their Merit, they have no elements.
        var contains: bool = false
        for removal in removals:
            if removal.key == record.key:
                contains = true
                break
        if contains:
            continue

        #If we were passed tips, use those for the starting point.
        if not tips.isNil:
            try:
                start = tips[record.key]
            except KeyError as e:
                doAssert(false, "Reloading Epochs from the DB using invalid tips: " & e.msg)
        #Else, use the holder's archived.
        else:
            start = consensus[record.key].archived

        #Grab the Verifs.
        try:
            elements = consensus[record.key][start .. record.nonce]
        #This will be thrown if we access a nonce too high, which shouldn't happen as we check a Block only has valid tips.
        except IndexError as e:
            doAssert(false, "An invalid tip was passed to shift: " & e.msg)

        #Iterate over every Verification.
        for element in elements:
            if element of Verification:
                #Try adding this hash to an existing Epoch.
                try:
                    epochs.add(cast[Verification](element).hash, element.holder)
                #If it wasn't in any existing Epoch, add it to the new one.
                except NotInEpochs:
                    newEpoch.add(cast[Verification](element).hash, element.holder)

        #If we were passed a set of tips, update them.
        if not tips.isNil:
            tips[record.key] = record.nonce

    #Return the popped Epoch.
    result = epochs.shift(newEpoch, not tips.isNil)

#Constructor. Below shift as it calls shift.
proc newEpochs*(
    db: DB,
    consensus: Consensus,
    blockchain: Blockchain
): Epochs {.forceCheck: [].} =
    #Create the Epochs objects.
    result = newEpochsObj(db)

    #Regenerate the Epochs.
    var
        #Use the Holders from the State.
        holders: seq[BLSPublicKey] = db.loadHolders()
        #Table of every archived tip before the current Epochs.
        tips: TableRef[BLSPublicKey, int] = newTable[BLSPublicKey, int]()

    #Shift the last 10 blocks. Why?
    #We want to regenerate the Epochs for the last 5, but we need to regenerate the 5 before that so late elements aren't labelled as first appearances.
    try:
        for b in max(blockchain.height - 10, 0) ..< blockchain.height:
            #See if any MeritHolders lost Merit.
            var removals: seq[MeritHolderRecord] = @[]
            for record in blockchain[b].records:
                try:
                    if tips[record.key] == record.nonce - 1:
                        if consensus[record.key][record.nonce] of MeritRemoval:
                            removals.add(record)
                except KeyError as e:
                    doAssert(false, "Either a MeritHolder with no Merit had an Element archived or we couldn't load an Element archived in a Block saved to the disk: " & e.msg)

            discard result.shift(
                consensus,
                removals,
                blockchain[b].records,
                tips
            )
    except IndexError as e:
        doAssert(false, "Couldn't shift the last blocks of the chain: " & e.msg)

#Calculate what share each holder deserves of the minted Meros.
proc calculate*(
    epoch: Epoch,
    state: var State
): seq[Reward] {.forceCheck: [].} =
    #If the epoch is empty, do nothing.
    if epoch.hashes.len == 0:
        return @[]

    var
        #Total Merit behind an Transaction.
        weight: int
        #Score of a holder.
        scores: Table[BLSPublicKey, uint64] = initTable[BLSPublicKey, uint64]()
        #Total score.
        total: uint64
        #Total normalized score.
        normalized: int

    #Find out how many Verifications for verified Transactions were created by each Merit Holder.
    for tx in epoch.hashes.keys():
        #Clear the loop variable.
        weight = 0

        try:
            #Iterate over every holder who verified a tx.
            for holder in epoch.hashes[tx]:
                #Add their Merit to the Transaction's weight.
                weight += state[holder]
        except KeyError as e:
            doAssert(false, "Couldn't grab the verifiers for a hash in the Epoch grabbed from epoch.hashes.keys(): " & e.msg)

        #Make sure the Transaction was verified.
        if weight < ((state.live div 2) + 1):
            continue

        #If it was, increment every verifier's score.
        try:
            for holder in epoch.hashes[tx]:
                if not scores.hasKey(holder):
                    scores[holder] = 0
                scores[holder] += 1
        except KeyError as e:
            doAssert(false, "Either couldn't grab the verifiers for an Transaction in the Epoch or the score of a holder: " & e.msg)

    #Multiply every score by how much Merit the holder has.
    try:
        for holder in scores.keys():
            scores[holder] = scores[holder] * uint64(state[holder])
            #Add the update score to the total.
            total += scores[holder]
    except KeyError as e:
        doAssert(false, "Couldn't update a holder's score despite grabbing the holder by scores.keys(): " & e.msg)

    #Turn the table into a seq.
    result = newSeq[Reward]()
    try:
        for holder in scores.keys():
            result.add(
                newReward(
                    holder,
                    scores[holder]
                )
            )
    except KeyError as e:
        doAssert(false, "Couldn't grab the score of a holder grabbed from scores.keys(): " & e.msg)

    #Sort them by greatest score.
    result.sort(
        func (
            x: Reward,
            y: Reward
        ): int {.forceCheck: [].} =
            #Extract the keys.
            var
                xKey: string = x.key.toString()
                yKey: string = y.key.toString()

            if x.score > y.score:
                result = 1
            elif x.score == y.score:
                for b in 0 ..< xKey.len:
                    if xKey[b] > yKey[b]:
                        return 1
                    elif xKey[b] == yKey[b]:
                        continue
                    else:
                        return -1
                doAssert(false, "Epochs generated two rewards for the same key.")
            else:
                result = -1
        , SortOrder.Descending
    )

    #Delete everything after 100.
    if result.len > 100:
        result.delete(100, result.len - 1)

    #Normalize each holder to a share of 1000.
    for i in 0 ..< result.len:
        result[i].score = result[i].score * 1000 div total
        normalized += int(result[i].score)

    #If the score isn't a perfect 1000, attribute everything left over to the top verifier.
    if normalized < 1000:
        result[0].score += uint64(1000 - normalized)
