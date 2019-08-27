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

#Compare two Consensuses to make sure they have the same value.
proc compare*(
    c1: Consensus,
    c2: Consensus
) =
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

    #Verify the Unknowns.
    assert(c1.unknowns.len == 0)
    assert(c2.unknowns.len == 0)
