#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib (for BLSPublicKey's toString).
import ../../Wallet/MinerWallet

#Verifications lib.
import ../Verifications/Verifications

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#VerifierRecord object.
import ../common/objects/VerifierRecordObj

#Blockcain and State lib.
import Blockchain
import State

#Epoch objects.
import objects/EpochsObj
export EpochsObj

#Finals lib.
import finals

#Sequtils standard lib (used to remove Rewards).
import sequtils

#Algorithm standard lib (used to sort Rewards).
import algorithm

#Tables standard lib.
import tables

#This shift does four things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
# - Saves the VerifierRecordes in the Epoch to-be-returned to the Database.
#If tips is provided, which it is when loading from the DB, those are used instead of verifier.archived.
proc shift*(
    epochs: var Epochs,
    verifications: var Verifications,
    records: seq[VerifierRecord],
    tips: TableRef[string, int] = nil
): Epoch {.forceCheck: [].} =
    var
        #New Epoch for any Verifications belonging to Entries that aren't in an older Epoch.
        newEpoch: Epoch = newEpoch(records)
        #Loop variable of what verification to start with.
        start: int
        #Verifications we're handling.
        verifs: seq[Verification]

    #Loop over each Verification.
    for record in records:
        #If we were passed tips, use those for the starting point.
        if not tips.isNil:
            try:
                start = tips[record.key.toString()]
            except KeyError as e:
                doAssert(false, "Reloading Epochs from the DB using invalid tips: " & e.msg)
        #Else, use the verifier's archived.
        else:
            start = verifications[record.key].archived

        #Grab the Verifs.
        try:
            verifs = verifications[record.key][start .. int(record.nonce)]
        #This will be thrown if we access a verif too high, which shouldn't happen as we check a Block only has valid tips.
        except IndexError as e:
            doAssert(false, "An invalid tip was passed to shift: " & e.msg)

        #Iterate over every Verification.
        for verif in verifs:
            #Try adding this hash to an existing Epoch.
            try:
                epochs.add(verif.hash.toString(), verif.verifier)
            #If it wasn't in any existing Epoch, add it to the new one.
            except NotInEpochs:
                newEpoch.add(verif.hash.toString(), verif.verifier)

        #If we were passed a set of tips, update them.
        if not tips.isNil:
            tips[record.key.toString()] = record.nonce

    #Return the popped Epoch.
    result = epochs.shift(newEpoch, records, tips.isNil)

#Constructor. Below shift as it calls shift.
proc newEpochs*(
    db: DatabaseFunctionBox,
    verifications: var Verifications,
    blockchain: Blockchain
): Epochs {.forceCheck: [].} =
    #Create the Epochs objects.
    result = newEpochsObj(db)

    #Regenerate the Epochs.
    var
        #String of every holder.
        holders: string
        #Table of every archived tip before the current Epochs.
        tips: TableRef[string, int] = newTable[string, int]()

    try:
        holders = db.get("merit_holders")
    except DBReadError:
        #If there are no holders, there's no mined Blocks and therefore no Epochs to regenerate.
        holders = ""

    #We don't just return in the above except in case an empty holders is saved to the DB.
    #That should be impossible, as the State, as of right now, only saves the holders once it has some.
    #That said, if we change how the State operates the DB, it shouldn't break this.
    if holders == "":
        return

    #Use the Holders string from the State.
    for i in countup(0, holders.len - 1, 48):
        #Extract the holder.
        var holder = holders[i .. i + 47]

        #Load their tip.
        try:
            tips[holder] = db.get("merit_" & holder & "_epoch").fromBinary()
        except DBReadError:
            #If this failed, it's because they have Merit but don't have Verifications older than 5 blocks.
            tips[holder] = 0

    #Shift the last 10 blocks. Why?
    #We want to regenerate the Epochs for the last 5, but we need to regenerate the 5 before that so late verifications aren't labelled as first appearances.
    var start: int = 10
    #If the blockchain is smaller than 10, load every block.
    if blockchain.height < 10:
        start = blockchain.height

    try:
        for i in countdown(start, 1):
            discard result.shift(
                verifications,
                blockchain[blockchain.height - i].records,
                tips
            )
    except IndexError as e:
        doAssert(false, "Couldn't shift the last blocks of the chain: " & e.msg)

#Calculate what share each person deserves of the minted Meros.
func calculate*(
    epoch: Epoch,
    state: var State
): Rewards {.forceCheck: [].} =
    #If the epoch is empty, do nothing.
    if epoch.len == 0:
        return @[]

    var
        #Score of a person. This is their combined normalized Entry values.
        scores: Table[string, int] = initTable[string, int]()
        #Total Merit behind an Entry.
        total: int

    #Iterate over each Entry.
    for entry in epoch.keys():
        #Clear the loop variables.
        #We use result as a loop variable because we don't need it till later.
        result = newRewards()
        total = 0

        #Iterate over the result who verified an entry.
        try:
            for person in epoch[entry]:
                #Add them to our seq with their Merit.
                result.add(
                    newReward(
                        person.toString(),
                        state[person]
                    )
                )
                #Add the Merit to the total.
                total += result[^1].score
        except KeyError as e:
            doAssert(false, "Couldn't grab the keys for a hash in the Epoch guaranteed to exist: " & e.msg)

        #Make sure the Entry was verified.
        if total < ((state.live div 2) + 1):
            #If it wasn't, move on.
            continue

    try:
        #Normalize each person to a share of 1000.
        for person in result:
            #Make sure they have a score.
            if not scores.hasKey(person.key):
                scores[person.key] = 0

            #Add this to their score.
            scores[person.key] += person.score * 1000 div total
    except KeyError as e:
        doAssert(false, "Couldn't set the score of a person guaranteed to be in the table: " & e.msg)

    #Turn the table into a seq.
    #Here's where we clear result and actually put in the data that will be returned.
    result = newRewards()
    try:
        for key in scores.keys():
            result.add(
                newReward(
                    key,
                    scores[key]
                )
            )
    except KeyError as e:
        doAssert(false, "Couldn't grab the score of a key grabbed from table.keys(): " & e.msg)

    #Make sure we're dealing with a maximum of 100 results.
    if epoch.len > 100:
        #Sort them by greatest score.
        result.sort(
            func (
                x: Reward,
                y: Reward
            ): int =
                if x.score > y.score:
                    result = 1
                elif x.score == y.score:
                    result = 0
                else:
                    result = -1
            , SortOrder.Descending
        )

        #Declare the cutoff edge.
        var edge: int = 100
        #If the result at the edge are tied...
        while result[edge-1].score == result[edge].score:
            #Increase the edge.
            inc(edge)

        #Delete everything after the edge.
        result.delete(edge, result.len-1)

    #Reuse total to calculate the total score.
    total = 0
    for person in result:
        total += person.score

    #Normalize each person to a score of 1000.
    try:
        for i in 0 ..< result.len:
            result[i].score = result[i].score * 1000 div total
    except FinalAttributeError as e:
        doAssert(false, "Couldn't normalize the scores of the Verifiers due to finals: " & e.msg)
