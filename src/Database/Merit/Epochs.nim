#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Consensus lib.
import ../Consensus/Consensus

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

#Get the packets the specified Block archives.
#As this uses a Blockchain as the first argument, it should be in Blockchain at first glance.
#That said, it's only used to shift a new Epoch and reload Epochs at this time.
proc getPackets*(
    blockchain: Blockchain,
    consensus: Consensus,
    nonce: int
): Table[Hash[384], VerificationPacket] {.forceCheck: [].} =
    initTable[Hash[384], VerificationPacket]()

#This shift does three things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
proc shift*(
    epochs: var Epochs,
    newBlock: Block,
    packets: Table[Hash[384], VerificationPacket]
): Epoch {.forceCheck: [].} =
    var
        #New Epoch for any Verifications belonging to Transactions that aren't in an older Epoch.
        newEpoch: Epoch = newEpoch()
        #Epoch the hash is in.
        e: int
        #Packet for the hash.
        packet: VerificationPacket

    #Loop over every hash.
    for hash in newBlock.body.transactions:
        #Grab the packet.
        try:
            packet = packets[hash]
        except KeyError as e:
            doAssert(false, "Shifting a hash without the matching VerificationPacket: " & e.msg)

        #Find out what Epoch the hash is in.
        e = 0
        while true:
            if epochs[e].hasKey(hash):
                break

            #If it's not in any, add the packet to the new Epoch.
            if e == 5:
                #Create a seq for the Transaction.
                newEpoch.register(hash)

                #Add the packet.
                newEpoch.add(packet)
                break

        #If it was in an existing Epoch, add it to said Epoch.
        if e != 5:
            epochs[e].add(packet)

    #Return the popped Epoch.
    result = epochs.shift(newEpoch)

#Constructor. Below shift as it calls shift.
proc newEpochs*(
    consensus: Consensus,
    blockchain: Blockchain
): Epochs {.forceCheck: [].} =
    #Create the Epochs objects.
    result = newEpochsObj()

    #Regenerate the Epochs. To do this, we shift the last 10 blocks. Why?
    #We want to regenerate the Epochs for the last 5, but we need to regenerate the 5 before that so late elements aren't labelled as first appearances.
    for b in max(blockchain.height - 10, 0) ..< blockchain.height:
        #Gather the packets for these Blocks.
        var packets: Table[Hash[384], VerificationPacket] = blockchain.getPackets(consensus, b)

        #Shift the Block.
        try:
            discard result.shift(blockchain[b], packets)
        except IndexError as e:
            doAssert(false, "Couldn't shift the last 10 Blocks from the chain: " & e.msg)

#Calculate what share each holder deserves of the minted Meros.
proc calculate*(
    epoch: Epoch,
    state: var State
): seq[Reward] {.forceCheck: [].} =
    #If the epoch is empty, do nothing.
    if epoch.len == 0:
        return @[]

    var
        #Total Merit behind an Transaction.
        weight: int
        #Score of a holder.
        scores: Table[uint16, uint64] = initTable[uint16, uint64]()
        #Total score.
        total: uint64
        #Total normalized score.
        normalized: int

    #Find out how many Verifications for verified Transactions were created by each Merit Holder.
    for tx in epoch.keys():
        #Clear the loop variable.
        weight = 0

        try:
            #Iterate over every holder who verified a tx.
            for holder in epoch[tx]:
                #Add their Merit to the Transaction's weight.
                weight += state[holder]
        except KeyError as e:
            doAssert(false, "Couldn't grab the verifiers for a hash in the Epoch grabbed from epoch.keys(): " & e.msg)

        #Make sure the Transaction was verified.
        if weight < ((state.live div 2) + 1):
            continue

        #If it was, increment every verifier's score.
        try:
            for holder in epoch[tx]:
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
            if x.score > y.score:
                result = 1
            elif x.score == y.score:
                if x.nick > y.nick:
                    return 1
                elif x.nick == y.nick:
                    doAssert(false, "Epochs generated two rewards for the same nick.")
                else:
                    return -1
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
