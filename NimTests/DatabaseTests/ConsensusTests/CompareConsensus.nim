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

#Compare two MeritHolders to make sure they have the same value.
proc compare*(
    mh1: MeritHolder,
    mh2: MeritHolder
) =
    #Test both have the same fields.
    assert(mh1.key == mh2.key)
    assert(mh1.archived == mh2.archived)
    assert(mh1.merkle.hash == mh2.merkle.hash)

    #Test the Elements.
    for i in 0 .. mh1.archived:
        compare(mh1[i], mh2[i])

#Compare two Transaction Statuses to make sure they have the samew value.
proc compare*(
    ts1: TransactionStatus,
    ts2: TransactionStatus
) =
    assert(ts1.epoch == ts2.epoch)
    assert(ts1.defaulting == ts2.defaulting)
    assert(ts1.verified == ts2.verified)

    assert(ts1.verifiers.len == ts2.verifiers.len)
    for v in 0 ..< ts1.verifiers.len:
        assert(ts1.verifiers[v] == ts2.verifiers[v])

#Compare two Consensuses to make sure they have the same value.
proc compare*(
    c1: Consensus,
    c2: Consensus
) =
    #Compare the SpamFilters.
    assert(c1.filters.send.difficulty == c2.filters.send.difficulty)
    assert(c1.filters.data.difficulty == c2.filters.data.difficulty)

    #Get the holders.
    var
        c1Holders: seq[BLSPublicKey] = @[]
        c2Holders: seq[BLSPublicKey] = @[]
    for holder in c1.holders:
        c1Holders.add(holder)
    for holder in c2.holders:
        c2Holders.add(holder)

    #Compare the holders.
    assert(c1Holders.len == c2Holders.len)
    for holder in c1Holders:
        assert(c2Holders.contains(holder))
        compare(c1[holder], c2[holder])

    #Compare the statuses.
    for status in c1.statuses:
        compare(c1.getStatus(status.toHash(384)), c2.getStatus(status.toHash(384)))

    #Compare the unmentioned.
    assert(c1.unmentioned.len == c2.unmentioned.len)
    for hash in c1.unmentioned.keys():
        assert(c2.unmentioned.hasKey(hash))

    #Verify the Unknowns.
    assert(c1.unknowns.len == 0)
    assert(c2.unknowns.len == 0)
