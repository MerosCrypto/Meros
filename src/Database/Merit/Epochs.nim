#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Verifications objects.
import ../Verifications/Verifications

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#VerifierIndex object.
import objects/VerifierIndexObj

#State object.
import objects/StateObj

#Epoch objects.
import objects/EpochsObj
export EpochsObj

#Finals lib.
import finals

#Seq utils standard lib.
import sequtils

#Algorithm standard lib.
import algorithm

#Tables standard lib.
import tables

#Calculate what share each person deserves of the minted Meros.
proc calculate*(
    epoch: Epoch,
    state: State
): Rewards {.raises: [
    KeyError
].} =
    #If the epoch is empty, do nothing.
    if epoch.verifications.len == 0:
        return @[]

    var
        #Score of a person. This is their combined normalized Entry values.
        scores: TableRef[string, uint] = newTable[string, uint]()
        #Total Merit behind an Entry.
        total: uint

    #Iterate over each Entry.
    for entry in epoch.verifications.keys():
        #Clear the loop variables.
        #We use result as a loop variable because we don't need it till later.
        result = newRewards()
        total = 0

        #Iterate over the result who verified an entry.
        for person in epoch.verifications[entry]:
            #Add them to our seq with their Merit.
            result.add(
                newReward(
                    person.toString(),
                    state[person]
                )
            )
            #Add the Merit to the total.
            total += result[^1].score

        #Make sure the Entry was verified.
        if total < ((state.live div uint(2)) + 1):
            #If it wasn't, move on.
            continue

        #Normalize each person to a share of 1000.
        for person in result:
            #Make sure they have a score.
            if not scores.hasKey(person.key):
                scores[person.key] = 0

            #Add this to their score.
            scores[person.key] += person.score * 1000 div total

    #Turn the table into a seq.
    #Here's where we clear result and actually put in the data that will be returned.
    result = newRewards()
    for key in scores.keys():
        result.add(
            newReward(
                key,
                scores[key]
            )
        )

    #Make sure we're dealing with a maximum of 100 results.
    if epoch.verifications.len > 100:
        #Sort them by greatest score.
        result.sort(
            proc (
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
    for i in 0 ..< result.len:
        result[i].score = result[i].score * 1000 div total

#This shift is used for regenerating the Epochs on boot.
proc shift*(
    epochs: Epochs,
    verifs: Verifications,
    indexes: seq[VerifierIndex],
    tips: TableRef[string, uint],
    ignore: TableRef[string, bool]
) {.raises: [
    KeyError,
    ValueError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    var
        newEpoch: Epoch = newEpoch(indexes)
        found: bool

    for index in indexes:
        for verif in verifs[index.key][tips[index.key], index.nonce]:
            found = false

            for epoch in epochs.epochs:
                #If we're supposed to ignore this hash, because it's in an Epoch before the ones we're regenerating, break.
                if ignore[verif.hash.toString()]:
                    break

                if epoch.verifications.hasKey(verif.hash.toString()):
                    found = true
                    epoch.verifications[verif.hash.toString()].add(verif.verifier)
                    break

            if not found:
                newEpoch.verifications[verif.hash.toString()] = @[
                    verif.verifier
                ]

        #Update the tip,
        tips[index.key] = index.nonce

    epochs.epochs.add(newEpoch)
    epochs.epochs.delete(0)

#This shift does four things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
# - Saves the VerifierIndexes in the Epoch to-be-returned to the Database.
proc shift*(
    epochs: Epochs,
    verifs: Verifications,
    indexes: seq[VerifierIndex]
): Epoch {.raises: [
    KeyError,
    ValueError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    var
        #New Epoch for any Verifications belonging to Entries that aren't in an older Epoch.
        newEpoch: Epoch = newEpoch(indexes)
        #A loop variable saying if we found the Entry in an older Epoch.
        found: bool

    #Loop over each Verification.
    for index in indexes:
        for verif in verifs[index.key][verifs[index.key].archived, int(index.nonce)]:
            #Set found to false.
            found = false

            #Iterate over each Epoch to find which has the Entry.
            for epoch in epochs.epochs:
                #If this Epoch has it, set found to true, and add it.
                if epoch.verifications.hasKey(verif.hash.toString()):
                    found = true
                    epoch.verifications[verif.hash.toString()].add(verif.verifier)
                    #Don't waste time by searching the others.
                    break

            #If it wasn't found, create a seq for it in the newest Epoch.
            if not found:
                newEpoch.verifications[verif.hash.toString()] = @[
                    verif.verifier
                ]

    #Add the newest Epoch.
    epochs.epochs.add(newEpoch)
    #Set the result to the oldest.
    result = epochs.epochs[0]
    #Remove the oldest.
    epochs.epochs.delete(0)

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
