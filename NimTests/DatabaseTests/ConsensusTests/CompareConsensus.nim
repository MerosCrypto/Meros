#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Tables standard lib.
import tables

#Compare two Verifications to make sure they have the same value.
proc compare*(
    e1: Element,
    e2: Element
) =
    assert(e1 == e2)

#Compare two Transaction Statuses to make sure they have the same values.
proc compare*(
    ts1: TransactionStatus,
    ts2: TransactionStatus
) =
    #Compare the Transaction's properties.
    assert(ts1.epoch == ts2.epoch)
    assert(ts1.competing == ts2.competing)
    assert(ts1.verified == ts2.verified)
    assert(ts1.beaten == ts2.beaten)

    #Compare the Transaction's holders.
    assert(ts1.holders.len == ts2.holders.len)
    for h in ts1.holders.keys():
        assert(ts1.holders[h] == ts1.holders[h])

    #Compare the pending VerificationPackets.
    compare(ts1.pending, ts2.pending)

    #Compare the pending signatures table.
    assert(ts1.signatures.len == ts2.signatures.len)
    for h in ts1.signatures.keys():
        assert(ts1.signatures[h] == ts1.signatures[h])

    #Compare the merit table.
    assert(ts1.merit == ts2.merit)

#Compare two Consensuses to make sure they have the same values.
proc compare*(
    c1: Consensus,
    c2: Consensus
) =
    #Compare the SpamFilters.
    assert(c1.filters.send.difficulty == c2.filters.send.difficulty)
    assert(c1.filters.data.difficulty == c2.filters.data.difficulty)

    #Compare the malicious table.
    assert(c1.malicious.len == c2.malicious.len)
    for nick in c1.malicious.keys():
        assert(c1.malicious[nick] == c2.malicious[nick])

    #Compare the statuses table.uses.len)
    for hash in c1.statuses.keys():
        compare(c1.statuses[hash], c2.statuses[hash])

    #Compare the close table.
    #We don't compare the length as c2 can have more Transactions if their verifiers gained Merit.
    #If we only reloaded Transactions which are still close, we wouldn't have more Transactions, yet we would have less.
    #That would rewrite the check to `for hash in c2.close.keys(): assert(c1.close.hasKey(hash))`.
    for hash in c1.close.keys():
        assert(c2.close.hasKey(hash))

    #Compare the unmentioned table.
    assert(c1.unmentioned.len == c2.unmentioned.len)
    for hash in c1.unmentioned.keys():
        assert(c1.unmentioned[hash] == c2.unmentioned[hash])
