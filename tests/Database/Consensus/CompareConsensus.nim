#Test lib.
import unittest

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Algorithm standard lib.
import algorithm

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
        proc maliciousSort(
            x: SignedMeritRemoval,
            y: SignedMeritRemoval,
        ): int =
            if x.reason < y.reason:
                return -1
            else:
                return 1

        var
            c1Malicious: seq[SignedMeritRemoval] = c1.malicious[nick].sorted(maliciousSort)
            c2Malicious: seq[SignedMeritRemoval] = c2.malicious[nick].sorted(maliciousSort)

        check(c1Malicious.len == c2Malicious.len)
        for r in 0 ..< c1Malicious.len:
            check(cast[Element](c1Malicious[r]) == cast[Element](c2Malicious[r]))
            check(c1Malicious[r].signature == c2Malicious[r].signature)

    #Compare the statuses table.
    check(c1.statuses.len == c2.statuses.len)
    for hash in c1.statuses.keys():
        compare(c1.statuses[hash], c2.statuses[hash])

    #Compare the unmentioned set.
    check(symmetricDifference(c1.unmentioned, c2.unmentioned).len == 0)

    #Check the signatures table.
    check(c1.signatures.len == c2.signatures.len)
    for holder in c1.signatures.keys():
        check(c1.signatures[holder].len == c2.signatures[holder].len)
        for s in 0 ..< c1.signatures[holder].len:
            check(c1.signatures[holder][s] == c2.signatures[holder][s])

    #Comoare the archived table.
    check(c1.archived.len == c2.archived.len)
    for holder in c1.archived.keys():
        check(c1.archived[holder] == c2.archived[holder])
