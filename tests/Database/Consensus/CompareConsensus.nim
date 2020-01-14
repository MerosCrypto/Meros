#Test lib.
import unittest

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Compare two Verifications to make sure they have the same value.
proc compare*(
    e1: Element,
    e2: Element
) =
    check(e1 == e2)

#Compare two Transaction Statuses to make sure they have the same values.
proc compare*(
    ts1: TransactionStatus,
    ts2: TransactionStatus
) =
    #Compare the Transaction's properties.
    check(ts1.epoch == ts2.epoch)
    check(ts1.competing == ts2.competing)
    check(ts1.verified == ts2.verified)
    check(ts1.beaten == ts2.beaten)

    #Compare the Transaction's holders.
    check(symmetricDifference(ts1.holders, ts2.holders).len == 0)

    #Compare the pending VerificationPackets.
    compare(ts1.pending, ts2.pending)

    #Compare the pending signatures table.
    check(ts1.signatures.len == ts2.signatures.len)
    for h in ts1.signatures.keys():
        check(ts1.signatures[h] == ts2.signatures[h])

    #Compare the merit table.
    check(ts1.merit == ts2.merit)

#Compare two Spam Filters.
proc compare*(
    sf1: SpamFilter,
    sf2: SpamFilter
) =
    #Verify the median position and left/right are the same.
    check(sf1.medianPos == sf2.medianPos)
    check(sf1.left == sf2.left)
    check(sf1.right == sf2.right)

    #Verify the difficulties are the same.
    check(sf1.difficulties.len == sf2.difficulties.len)
    for d in 0 ..< sf1.difficulties.len:
        check(sf1.difficulties[d].difficulty == sf2.difficulties[d].difficulty)
        check(sf1.difficulties[d].votes == sf2.difficulties[d].votes)

    #Verify the SpamFilters agree on who voted for what.
    check(sf1.votes.len == sf2.votes.len)
    for holder in sf1.votes.keys():
        check(sf1.votes[holder].difficulty == sf2.votes[holder].difficulty)

    #Verify the starting difficulty and current difficulty.
    check(sf1.startDifficulty == sf2.startDifficulty)
    check(sf1.difficulty == sf2.difficulty)

#Compare two Consensuses to make sure they have the same values.
proc compare*(
    c1: Consensus,
    c2: Consensus
) =
    #Compare the SpamFilters.
    compare(c1.filters.send, c2.filters.send)
    compare(c1.filters.data, c2.filters.data)

    #Compare the malicious table.
    check(c1.malicious.len == c2.malicious.len)
    for nick in c1.malicious.keys():
        check(c1.malicious[nick] == c2.malicious[nick])

    #Compare the statuses table.uses.len)
    for hash in c1.statuses.keys():
        compare(c1.statuses[hash], c2.statuses[hash])

    #Compare the close table.
    #We don't compare the length as c2 can have more Transactions if their verifiers gained Merit.
    #If we only reloaded Transactions which are still close, we wouldn't have more Transactions, yet we would have less.
    #That would rewrite the check to `for hash in c2.close.keys(): check(c1.close.hasKey(hash))`.
    for hash in c1.close:
        check(c2.close.contains(hash))

    #Compare the unmentioned table.
    check(symmetricDifference(c1.unmentioned, c2.unmentioned).len == 0)
